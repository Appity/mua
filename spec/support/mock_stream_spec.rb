require_relative 'mock_stream'

RSpec.describe MockStream do
  it 'can create a new Async::IO::Stream' do
    stream = MockStream.new("example\r\n")

    expect(stream).to be_kind_of(Async::IO::Stream)
    expect(stream).to_not be_eof

    expect(stream.read_until("\r\n", chomp: true)).to eq('example')
    expect(stream).to be_eof
  end

  it 'can create a Mua::State::Context' do
    context = MockStream.context("example\n")

    expect(context).to be_kind_of(Mua::State::Context)
    expect(context.input).to be_kind_of(Async::IO::Stream)

    expect(context.input.read_until("\n", chomp: true)).to eq('example')
    expect(context.input).to be_eof
  end

  it 'can create a Mua::State::Context and writable IO pair' do
    Async do
      context, io = MockStream.context_writable_io

      expect(context).to be_kind_of(Mua::State::Context)
      expect(context.input).to be_kind_of(Async::IO::Stream)
      expect(io).to be_kind_of(Async::IO::Stream)

      io.puts('example')

      expect(context.input.gets.chomp).to eq('example')
    end
  end
end
