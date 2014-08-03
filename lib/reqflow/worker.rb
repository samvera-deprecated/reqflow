module Reqflow
  class Worker
    attr_reader :config, :payload
    
    def initialize(config, payload)
      @config = config
      @payload = payload
    end
    
    def do_work
    end
  end
end
