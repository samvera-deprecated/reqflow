require File.expand_path('../../spec_helper',__FILE__)

describe Reqflow::Instance do
  subject { Reqflow::Instance.new 'spec_workflow', 'changeme:123' }

  before :each do
    Reqflow::Instance.root = File.expand_path('../..',__FILE__)
    subject.reset!(true)
  end
  
  it "should load" do
    expect(subject.workflow_id).to eq('spec_workflow')
  end
  
  it "should have actions" do
    expect(subject.actions.keys.length).to eq(6)
  end
  
  it "should be waiting" do
    expect(subject.status.values.uniq).to eq(['WAITING'])
    expect(subject.completed?).to be_falsey
    expect(subject.failed?).to be_falsey
    expect(subject.ready).to eq([:inspect])
  end
  
  it "should complete!" do
    subject.complete! :inspect
    expect(subject.status(:inspect)).to eq('COMPLETED')
    expect(subject.completed?).to be_falsey
    expect(subject.failed?).to be_falsey
    expect(subject.ready).to eq([:transcode_high, :transcode_medium, :transcode_low])
  end

  it "should skip!" do
    subject.complete! :inspect
    subject.complete! :transcode_low
    subject.skip!     :transcode_medium
    subject.complete! :transcode_high
    expect(subject.status(:transcode_medium)).to eq('SKIPPED')
    expect(subject.completed?(:transcode_medium)).to be_truthy
    expect(subject.completed?).to be_falsey
    expect(subject.failed?).to be_falsey
    expect(subject.ready).to eq([:distribute])
  end
  
  it "should fail!" do
    subject.complete! :inspect
    subject.complete! :transcode_high
    subject.fail! :transcode_medium, 'It had to fail. This is a test.'
    expect(subject.status(:transcode_medium)).to eq('FAILED')
    expect(subject.message(:transcode_medium)).to eq('It had to fail. This is a test.')
    expect(subject.message(:transcode_high)).to eq(nil)
    expect(subject.completed?).to be_falsey
    expect(subject.failed?).to be_truthy
    expect(subject.ready).to eq([:transcode_low])
    subject.complete! :transcode_low
    expect(subject.ready).to eq([])
  end
end
