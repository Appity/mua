require 'async/io/socket'
require 'async/io/stream'
require_relative '../support/mock_stream'

module SimulateExchange
  class Wrapper
    CRLF = "\r\n".freeze

    def initialize(interpreter_type, reactor, &block)
      @cio, @io = Async::IO::Socket.pair(:UNIX, :STREAM, 0).map do |io|
        Async::IO::Stream.new(io, sync: true)
      end

      @context = interpreter_type.context.new(input: @cio)
      @interpreter = interpreter_type.new(@context)

      @interpreter_task = reactor.async do
        @interpreter.run!
      end

      @test_task = reactor.async do |task|
        block.call(@context, self, task)
      end

    ensure
      @interpreter_task.stop
      @test_task.stop

      @cio.close
      @io.close
    end

    def run_dialog(rspec, script, close: true)
      if (hostname = script['hostname'])
        @context.hostname = hostname
      end

      script['dialog'].each do |cmd|
        if (data = cmd['recv'])
          self.puts(data)
        elsif (data = cmd['send'])
          rspec.expect(self.gets).to rspec.eq(data)
        elsif (data = cmd['deliver'])
          # @context.deliver
        elsif (data = cmd['quit'])
          @context.quit
        end
      end

      @io.close if (close)
    end

    def puts(*args)
      @io.puts(*args, separator: CRLF)
    end

    def gets
      @io.gets(CRLF)
    end

    # Write and call a block with the result
    def write(text)
      if (ENV['DEBUG'])
        puts 'send -> %s' % text.inspect
      end

      @io.puts(text, separator: CRLF)

      response = @io.gets(CRLF)

      if (ENV['DEBUG'])
        puts 'recv <- %s' % response.inspect
      end

      yield(response) if (block_given?)

      response
    end

    def method_missing(name, *args, &block)
      @io.send(name, *args, &block)
    end
  end

  def with_interpreter(interpreter_type, &block)
    Wrapper.new(interpreter_type, reactor, &block)
  end
end
