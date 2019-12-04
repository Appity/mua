require 'async/io/socket'
require 'async/io/stream'
require_relative '../support/mock_stream'

module SimulateExchange
  module DebugExtensions
    def gets(*args)
      super.tap { |v| $stdout.puts('recv: %s' % v.inspect) }
    end

    def puts(*args, separator: $/)
      $stdout.puts('send: %s' % (args.length > 1 ? args.inspect : args[0].inspect))
      super
    end
  end

  class Wrapper
    CRLF = "\r\n".freeze

    def initialize(interpreter_type, reactor, &block)
      @cio, @io = Async::IO::Socket.pair(:UNIX, :STREAM, 0).map do |io|
        Async::IO::Stream.new(io, sync: true).tap do |stream|
          if (ENV['DEBUG'])
            stream.extend(DebugExtensions)
          end
        end
      end

      @context = interpreter_type.context.new(input: @cio)

      @test_task = reactor.async do |task|
        block.call(@context, self, task)
      end

      @interpreter = interpreter_type.new(@context)

      @interpreter_task = reactor.async do |task|
        @context.reactor = task

        InterpreterDebugLog.interpreter_run!(@interpreter)
      end

      @messages = { }

      [ @interpreter_task, @test_task ].map(&:wait)

    ensure
      @interpreter_task&.stop
      @test_task&.stop

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
          [ data ].flatten.each do |message|
            message = Mua::SMTP::Message.new(message)
            message.id ||= SecureRandom.uuid + '@example.net'
            @messages[message.id] = message
            @context.deliver!(message)
          end
        elsif (data = cmd['quit'])
          @context.quit!
        elsif (data = cmd['verify_delivery'])
          [ data ].flatten.each do |delivery|
            message = @messages[delivery['id']]
            rspec.expect(message).to rspec.be_kind_of(Mua::SMTP::Message)

            delivery.each do |field, value|
              rspec.expect(message.send(field)).to rspec.eq(value)
            end
          end
        end
      end

      @io.close if (close)
    end

    def puts(*args)
      @io.puts(*args, separator: CRLF)
    end

    def gets
      @io.gets(CRLF, chomp: true)
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
