# NOTE: This nexting is necessary to establish the structure outside of the
#       ideal require order and to avoid creating a circular dependency.
module Mua
  module SMTP
    module Common
      module ContextExtensions
        def read_line
          # REFACTOR: There's probably a better way to handle this than
          #           by creating a task per readline operation but it needs
          #           to be an interruptable operation.

          # self.read_task = Async::Task.current.with_timeout(self.timeout) do
          self.read_task = Async do
            line = self.input.gets

            line and yield(line.chomp)
          end

          self.read_task.wait.tap do |line|
            self.log(:recv, line)
          end

          # FIX: Handle Async read interruptions

        rescue Async::Wrapper::Cancelled
          @state_target and context.transition!(state: @state_target).tap do
            @state_target = nil
          end or Mua::Token::Redo
        rescue Async::TimeoutError
          # Dead read, handle as if the thing's closed.
          nil
        ensure
          self.read_task = nil
          @state_target = nil
        end

        def read_exactly(exactly, unpack: nil)
          if (unpack)
            self.input.read_exactly(exactly).unpack(unpack)
          else
            self.input.read_exactly(exactly)
          end
        end

        def write(data)
          self.log(:send, data)
          self.input.write(data)
          self.input.flush
        end

        def reply(*lines)
          self.log(:send, *lines)
          self.input.puts(*lines, separator: Mua::Constants::CRLF)
        end

        def packreply(format, *data)
          self.input.write(data.pack(format))
          self.input.flush
        end

        def close!
          self.input.close
          self.connected = false
        end

        def log(channel, *data)
          # Override with extensions
        end

        def remote_addr
          if (remote_port)
            '%s:%d' % [ remote_ip, remote_port ]
          else
            remote_ip
          end
        end

        def assign_remote_ip!
          io = self.input.io

          case (io.remote_address.afamily)
          when Socket::AF_INET
            self.remote_ip, self.remote_port = io.remote_address.ip_unpack
          when Socket::AF_UNIX
            self.remote_ip = 'localhost'
            self.remote_port = nil
          end
        end

        def local_addr
          if (local_port)
            '%s:%d' % [ local_ip, local_port ]
          else
            local_ip
          end
        end

        def assign_local_ip!
          io = self.input.io

          case (io.remote_address.afamily)
          when Socket::AF_INET
            self.local_ip, self.local_port = io.local_address.ip_unpack
          when Socket::AF_UNIX
            self.local_ip = 'localhost'
            self.local_port = nil
          end
        end
      end
    end
  end
end
