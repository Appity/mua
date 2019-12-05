# NOTE: This nexting is necessary to establish the structure outside of the
#       ideal require order and to avoid creating a circular dependency.
module Mua
  module SMTP
    module Common
      module ContextExtensions
        def read_line
          self.read_task = self.reactor.async do
            if (line = self.input.gets)
              yield(line.chomp)
            elsif (@state_target)
              transition!(state: @state_target)
            end
          end.wait
      
          # FIX: Handle Async read interruptions
      
        ensure
          self.read_task = nil
          @state_target = nil
        end
        
        def write(data)
          self.input.write(data)
        end
      
        def reply(*lines)
          self.input.puts(*lines, separator: Mua::Constants::CRLF)
        end
      end
    end
  end
end
