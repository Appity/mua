require_relative '../../constants'

require_relative '../../client/context'

Mua::SOCKS5::Client::Standalone = Mua::Interpreter.define(
  name: 'Mua::SOCKS5::Client::Standalone',
  context: Mua::Client::Context
) do
  state(:initialize, Mua::SOCKS5::Client::Interpreter)

  state(:proxy_connected) do
    enter do |context|
      io = context.input.io

      [
        Async do
          loop do
            $stdin.wait_readable
            io.wait_writable
            io.write($stdin.read_nonblock(1024) || break)
          end

        rescue EOFError
          # End of input is expected
        rescue Errno::EPIPE, Errno::ECONNRESET, Errno::ECONNREFUSED, IOError
          # Normal networking errors
        rescue Async::Wrapper::Cancelled
          # Abandon loop
        ensure
          io.flush
          io.close_write
        end,
        Async do
          loop do
            io.wait_readable
            $stdout.write(io.read_nonblock(1024) || break)
          end

        # rescue Errno::EPIPE, Errno::ECONNRESET, Errno::ECONNREFUSED, Errno::ETIMEDOUT, IOError
        #   # Normal networking errors
        # rescue Async::Wrapper::Cancelled
        #   # Abandon loop
        end
      ].each(&:wait)

      context.transition!(state: :finished)

    ensure
      io&.close
    end
  end

  state(:proxy_failed) do
    enter do |context|
      # Dumy state to capture transition
    end
  end
end
