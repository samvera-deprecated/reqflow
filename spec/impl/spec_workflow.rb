module ReqflowSpec
  class Workflow < Reqflow::Worker
    def inspect(payload)
      raise "Unknown payload" if payload.nil?
      $stderr.puts "Inspecting #{payload}"
    end

    def transcode(payload)
      $stderr.puts "Transcoding #{payload} with #{@config['command_line']}"
    end
  end
  
  class Distributor < Reqflow::Worker
    def distribute(payload)
      $stderr.puts "Distributing #{payload}"
    end
  end
end
