require 'async/io/stream'
require 'socket'
require 'fcntl'

module MockStream
  MODE_DEFAULT = 'r'.freeze

  module SendReceiveHelper
    def puts(*args)
      super(*args, separator: "\r\n")
    end

    def gets
      super("\r\n", chomp: true)
    end
  end

  def self.new(string = '', mode = nil)
    Async::IO::Stream.new(StringIO.new(string, mode || MODE_DEFAULT))
  end

  def self.context(string = '', mode = nil)
    Mua::State::Context.new(
      input: Async::IO::Stream.new(StringIO.new(string, mode || MODE_DEFAULT))
    )
  end

  def self.context_writable_io(context_type = Mua::State::Context)
    sa, sb = Socket.pair(:UNIX, :STREAM, 0).map do |io|
      Async::IO::Stream.new(Async::IO.try_convert(io))
    end

    context = context_type.new(
      input: sa
    )

    sb.extend(SendReceiveHelper)

    if (block_given?)
      begin
        yield(context, sb)
      ensure
        [ sa, sb ].each(&:close)
      end
    else
      [ context, sb ]
    end
  end

  def self.line_exchange(interpreter_type, &block)
    context, io = self.context_writable_io(interpreter_type.context)

    interpreter = interpreter_type.new(context)

    Async do
      thread = Thread.new do
        interpreter.run!
      end

      yield(interpreter, context, io)

      thread.join
    end
  end
end
