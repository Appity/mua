require 'async/io/socket'
require 'async/io/stream'
require_relative '../support/mock_stream'

module SimulateExchange
  class Wrapper
    CRLF = "\r\n".freeze

    def initialize(interpreter_type, &block)
      Async do |task|
        @cio, @io = Async::IO::Socket.pair(:UNIX, :STREAM, 0).map do |io|
          Async::IO::Stream.new(io, sync: true)
        end

        @context = interpreter_type.context.new(input: @cio)
        @interpreter = interpreter_type.new(@context)

        @task = task

        Async do
          @interpreter.run!
        end

        Async do |t|
          block.call(@context, self, t)
        end
      end
    end

    def dialog_path(script)
      File.expand_path(script, File.expand_path('../smtp/dialog', __dir__))
    end

    def run_dialog(rspec, script)
      File.open(dialog_path(script)).each_line do |line|
        next unless (line.match(/\S/))

        sr, data = line.chomp.scan(/\A([<>])\s*(.*)\z/)[0]

        case (sr)
        when '>'
          self.puts(data)
        when '<'
          rspec.expect(self.gets).to rspec.eq(data)
        end
      end

      @io.close
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
    Wrapper.new(interpreter_type, &block)
  end
end
