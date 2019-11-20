require 'async/io/stream'

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

  def self.context_writable_io
    rio, wio = IO.pipe
    context = Mua::State::Context.new(
      input: Async::IO::Stream.new(rio)
    )

    [ context, wio ]
  end
end
