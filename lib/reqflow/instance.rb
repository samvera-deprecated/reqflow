require 'redis'
require 'resque'
require 'yaml'

module Reqflow
  class Instance
    include Reqflow::Callbacks
    
    TIME_LOG_FORMAT = '%Y-%m-%dT%H:%M:%S.%L%z'
    
    attr_reader :redis, :workflow_id, :name, :actions, :payload
    attr_accessor :queue, :auto_queue

    class << self
      def perform(workflow_id, action, pid)
        self.new(workflow_id,pid).run!(action)
      end
      
      def root
        @root ||= begin
          Rails.root
        rescue
          Pathname.new(File.expand_path('.'))
        end
      end
      
      def root=(path)
        path = Pathname.new(path) if path.is_a?(String)
        @root = path
      end
    end
    
    def initialize(config, payload)
      if config.is_a?(String)
        config = YAML.load(File.read(self.class.root.join('config','workflows',"#{config}.yml")))
      end
      
      (@redis = Resque.redis.dup).namespace = :reqflow
      @queue = 'med'
      @workflow_id = config[:workflow_id]
      @name = config[:name]
      @actions = config[:actions]
      @auto_queue = true
      @payload = payload
      verify_actions
      reset!
    end
    
    def log(*args)
      redis.rpush('log',([Time.now.strftime(TIME_LOG_FORMAT)]+args).join(' '))
      redis.ltrim('log', -1000, -1)
    end
    
    def verify_actions
      missing = []
      @actions.each_pair do |action, definition|
        if definition[:prereqs]
          missing += definition[:prereqs] - @actions.keys
        end
      end
      if missing.length > 0
        raise UnknownAction, "Unknown prerequisites: #{missing.uniq.inspect}"
      end
    end
    
    def job_key(ext)
      [workflow_id,"job_#{payload}".gsub(/:/,'_'),ext].compact.join(':')
    end

    def set(action, key, value)
      if value.nil?
        redis.hdel(job_key(action),key)
      else
        redis.hset(job_key(action),key,value)
      end
    end
    
    def get(action, key)
      redis.hget(job_key(action),key)
    end
    
    def reset!(force=false)
      @actions.keys.each { |action| status!(action, 'WAITING') if (force or status(action).nil?) }
    end
    
    def details(action=:all)
      if action == :all
        @actions.keys.inject({}) { |h,a| h[a] = details(a); h }
      else
        redis.hgetall(job_key(action))
      end
    end
    
    def status(action=:all)
      if action == :all
        @actions.keys.inject({}) { |h,a| h[a] = status(a); h }
      else
        raise UnknownAction, "Unknown action: #{action}" unless @actions.keys.include?(action)
        get(action,'status')
      end
    end
    
    def status!(action, new_status, message=nil)
      raise UnknownAction, "Unknown action: #{action}" unless @actions.keys.include?(action)
      self.class.status_changing(self, action, new_status, message) do
        redis.multi do
          set(action, 'status', new_status)
          message! action, message
          log action, payload, new_status, message.to_s.gsub(/\n/,' / ')
        end
      end
      status(action)
    end
    
    def message(action)
      get(action, 'message')
    end
    
    def message!(action, message)
      set(action, 'message', message)
    end
    
    def complete!(action, message=nil)
      status! action, 'COMPLETED', message
      queue! if @auto_queue
      status(action)
    end
    
    def skip!(action, message=nil)
      status! action, 'SKIPPED', message
      queue! if @auto_queue
      status(action)
    end

    def fail!(action, message=nil)
      status! action, 'FAILED', message
    end
    
    def run!(action)
      begin
        status! action, 'RUNNING'
        action_def = @actions[action]
        action_class = action_def[:class].split(/::/).inject(Module) do |mod,sym| 
          mod.const_get(sym.to_sym)
        end
        action_method = (action_def[:method] || action).to_sym
        action_class.new(action_def[:config]).send(action_method, payload)
        complete! action
      rescue Exception => e
        fail! action, "#{e.class}: #{e.message}"
        raise e
      end
    end
    
    def queue!(action=:all)
      if action == :all
        ready.collect { |a| queue! a }
      else
        status! action, 'QUEUED'
        Resque.push(self.queue, class: self.class, args: [workflow_id, action, payload])
        status(action)
      end
    end

    def queued?(action)
      status(action) == 'QUEUED'
    end
    
    def running?(action)
      status(action) == 'RUNNING'
    end
    
    def completed?(action=:all)
      if action == :all
        @actions.keys.all? { |a| completed?(a) }
      else
        ['COMPLETED','SKIPPED'].include? status(action)
      end
    end
    
    def failed?(action=:any)
      if action == :any
        @actions.keys.any? { |a| failed?(a) }
      else
        status(action) == 'FAILED'
      end
    end
    
    def waiting?(action)
      status(action) == 'WAITING'
    end
    
    def ready(action=:all)
      if action == :all
        @actions.keys.select { |a| ready(a) }
      else
        prereqs = @actions[action][:prereqs] || []
        waiting?(action) && prereqs.all? { |req| completed?(req) }
      end
    end
    
    def to_s
      status.inspect
    end
    
    def inspect
      "#<#{self.class.name}:#{'0x%14.14x' % (object_id<<1)} #{to_s}>"
    end
  end
end
