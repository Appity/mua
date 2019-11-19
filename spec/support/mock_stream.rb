require 'async/io/stream'

module MockStream
  def self.new(string = '')
    Async::IO::Stream.new(StringIO.new(string))
  end

  def self.context(string = '')
    Mua::State::Context.new(
      input: Async::IO::Stream.new(StringIO.new(string))
    )
  end

  def self.context_io(string = '')
    io = StringIO.new(string)
    context = Mua::State::Context.new(
      input: Async::IO::Stream.new(io)
    )

    [ context, io ]
  end
end
