require 'async/io/stream'
require 'socket'

module MockStream
  MODE_DEFAULT = 'r'.freeze

  def self.new(string = '', mode = nil)
    Async::IO::Stream.new(StringIO.new(string, mode || MODE_DEFAULT))
  end

  def self.context(string = '', mode = nil)
    Mua::State::Context.new(
      input: Async::IO::Stream.new(StringIO.new(string, mode || MODE_DEFAULT))
    )
  end

  def self.context_writable_io(context_type = Mua::State::Context)
    sa, sb = Socket.pair(:UNIX, :STREAM, 0)
    context = context_type.new(
      input: Async::IO::Stream.new(sa)
    )

    [ context, sb ]
  end
end
