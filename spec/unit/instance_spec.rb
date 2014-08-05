require File.expand_path('../../spec_helper',__FILE__)

describe Reqflow::Instance do
  
  describe 'root' do
    before :all do
      unless defined? ::Rails
        @mocked_rails = true
        class ::Rails; end
      end
    end
    
    after :all do
      Object.send(:remove_const, :Rails) if @mocked_rails
    end
    
    before :each do
      Reqflow::Instance.root = nil
    end
    
    it "should default to Rails.root" do
      allow(Rails).to receive(:root) { Pathname.new('/path/to/rails/root') }
      expect(Reqflow::Instance.root).to be_a(Pathname)
      expect(Reqflow::Instance.root.to_s).to eq('/path/to/rails/root')
    end
    
    it "should default to . if Rails is not present" do
      expect(Reqflow::Instance.root).to be_a(Pathname)
      expect(Reqflow::Instance.root.to_s).to eq(File.expand_path('.'))
    end    
  end
  
  describe 'workflow' do
    subject { Reqflow::Instance.new 'spec_workflow', 'changeme:123' }

    before :all do
      module ReqflowSpec
        class Workflow
          def initialize(config)
            @config = config
          end
          
          def inspect(payload)
            raise "Unknown payload" if payload.nil?
            $stderr.puts "Inspecting #{payload}"
          end
          
          def transcode(payload)
            $stderr.puts "Transcoding #{payload} with options #{config[:params][:command_line]}"
          end
          
          def distirbute(payload)
            $stderr.puts "Distributing #{payload}"
          end
          
          def cleanup(payload)
            $stderr.puts "Cleaning up #{payload}"
          end
        end
      end
    end
    
    after :all do
      Object.send(:remove_const, :ReqflowSpec)
    end
    
    before :each do
      Reqflow::Instance.root = File.expand_path('../..',__FILE__)
      Resque.redis.keys.each { |k| Resque.redis.del(k) }
      subject.reset!(true)
    end
    
    it "should load" do
      expect(subject.workflow_id).to eq('spec_workflow')
    end
    
    it "should have actions" do
      expect(subject.actions.keys.length).to eq(6)
    end
    
    it "should verify prerequisites" do
      config = {workflow_id: "spec_workflow", name: "Spec Workflow", auto_queue: false, actions: { inspect: { prereqs: [:unknown] } }}
      expect { Reqflow::Instance.new(config, 'changeme:123') }.to raise_error(Reqflow::UnknownAction)
    end

    it "should be waiting" do
      expect(subject.status.values.uniq).to eq(['WAITING'])
      expect(subject).not_to be_completed
      expect(subject).not_to be_failed
      expect(subject.ready).to eq([:inspect])
    end
    
    it "should complete!" do
      subject.auto_queue = false
      subject.complete! :inspect
      expect(subject.status(:inspect)).to eq('COMPLETED')
      expect(subject).not_to be_completed
      expect(subject).not_to be_failed
      expect(subject.ready).to eq([:transcode_high, :transcode_medium, :transcode_low])
    end

    it "should skip!" do
      subject.auto_queue = false
      subject.complete! :inspect
      subject.complete! :transcode_low
      subject.skip!     :transcode_medium
      subject.complete! :transcode_high
      expect(subject.status(:transcode_medium)).to eq('SKIPPED')
      expect(subject.completed?(:transcode_medium)).to be_truthy
      expect(subject).not_to be_completed
      expect(subject).not_to be_failed
      expect(subject.ready).to eq([:distribute])
    end
    
    it "should fail!" do
      subject.complete! :inspect
      subject.complete! :transcode_high
      subject.fail! :transcode_medium, 'It had to fail. This is a test.'
      expect(subject.status(:transcode_medium)).to eq('FAILED')
      expect(subject.status(:transcode_low)).to eq('QUEUED')
      expect(subject.message(:transcode_medium)).to eq('It had to fail. This is a test.')
      expect(subject.message(:transcode_high)).to eq(nil)
      expect(subject).not_to be_completed
      expect(subject).to be_failed
    end
    
    it "should queue actions" do
      expect(Resque).to receive(:push).with(instance_of(String), class: subject.class, args: ['spec_workflow', :inspect,          'changeme:123'])
      expect(Resque).to receive(:push).with(instance_of(String), class: subject.class, args: ['spec_workflow', :transcode_low,    'changeme:123'])
      expect(Resque).to receive(:push).with(instance_of(String), class: subject.class, args: ['spec_workflow', :transcode_medium, 'changeme:123'])
      expect(Resque).to receive(:push).with(instance_of(String), class: subject.class, args: ['spec_workflow', :transcode_high,   'changeme:123'])
      subject.queue!
      expect(subject).to be_queued(:inspect)
      expect(subject).to be_waiting(:transcode_high)
      expect(subject).to be_waiting(:transcode_medium)
      expect(subject).to be_waiting(:transcode_low)
      subject.complete!(:inspect)
      expect(subject).to be_completed(:inspect)
      expect(subject).to be_queued(:transcode_high)
      expect(subject).to be_queued(:transcode_medium)
      expect(subject).to be_queued(:transcode_low)
    end
    
    it "should perform an action" do
      expect($stderr).to receive(:puts).with('Inspecting changeme:123')
      Reqflow::Instance.perform('spec_workflow', :inspect, 'changeme:123')
      expect(subject.status(:inspect)).to eq('COMPLETED')
      expect(subject).to be_queued(:transcode_high)
      expect(subject).to be_queued(:transcode_medium)
      expect(subject).to be_queued(:transcode_low)
    end
    
    it "should know when an action is running" do
      wf = Reqflow::Instance.new 'spec_workflow', 'running?'
      expect(wf).to be_waiting(:inspect)
      expect_any_instance_of(ReqflowSpec::Workflow).to receive(:inspect).with('running?') { expect(wf).to be_running(:inspect) }
      Reqflow::Instance.perform('spec_workflow', :inspect, 'running?')
      expect(wf).to be_completed(:inspect)
    end
    
    it "should fail at an action" do
      wf = Reqflow::Instance.new 'spec_workflow', nil
      expect(wf).to be_waiting(:inspect)
      expect { Reqflow::Instance.perform('spec_workflow', :inspect, nil) }.to raise_error(RuntimeError)
      expect(wf).to be_failed(:inspect)
      expect(wf.message(:inspect)).to eq('RuntimeError: Unknown payload')
      expect(wf.ready).to be_empty
      expect(wf).to be_failed
    end
    
    it "should report details" do
      expect(subject.details).to be_a(Hash)
    end
    
    it "should represent itself as a string" do
      expect(subject.to_s)
      expect(subject.inspect)
    end
    
    describe 'callbacks' do
      before :each do
        Reqflow::Instance.before_status_change do |wf, action, new|
          $stderr.puts("#{wf.workflow_id} for #{wf.payload} is changing #{action} to #{new}")
        end

        Reqflow::Instance.after_status_change do |wf, action, new|
          $stderr.puts("#{wf.workflow_id} for #{wf.payload} changed #{action} to #{new}")
        end
      end
      
      after :each do
        Reqflow::Instance.reset_callbacks
      end
      
      it "should call callbacks" do
        ['inspect to COMPLETED','transcode_high to QUEUED','transcode_medium to QUEUED','transcode_low to QUEUED'].each do |change|
          expect($stderr).to receive(:puts).with("spec_workflow for changeme:123 is changing #{change}") 
          expect($stderr).to receive(:puts).with("spec_workflow for changeme:123 changed #{change}") 
        end
        subject.complete! :inspect
      end
    end
  end  
end
