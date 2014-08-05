module Reqflow
  module Callbacks
    def self.included(mod)      
      mod.class_eval do
        class << self          
          @@status_change = { before: [], after: [] }
          
          def reset_callbacks
            @@status_change = { before: [], after: [] }
          end

          def before_status_change &block
            @@status_change[:before] << block
            block
          end
          
          def after_status_change &block
            @@status_change[:after] << block
            block
          end
          
          def status_changing(wf, action, new_status, message)
            @@status_change[:before].each { |proc| 
              proc.call(wf, action, new_status, message)
            }
            yield
            @@status_change[:after].reverse.each { |proc| 
              proc.call(wf, action, new_status, message)
            }
          end
        end
      end
    end
  end
end
