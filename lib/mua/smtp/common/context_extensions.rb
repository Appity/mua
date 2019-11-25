# NOTE: This nexting is necessary to establish the structure outside of the
#       ideal require order and to avoid creating a circular dependency.
module Mua
  module SMTP
    module Common
      module ContextExtensions
        def read_line
          task = self.read_task = self.reactor.async do
            line = self.input.gets
      
            line and yield(line.chomp)
          end
      
          task.wait
      
          # FIX: Handle Async read interruptions
      
        ensure
          self.read_task = nil
        end
      
        def reply(*lines)
          self.input.puts(*lines, separator: Mua::Constants::CRLF)
        end
      end
    end
  end
end
