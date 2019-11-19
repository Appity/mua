require_relative 'mock_stream'

RSpec.describe MockStream do
  it 'can create a new Async::IO::Stream' do
    stream = MockStream.new('example')

    expect(stream).to be_kind_of(Async::IO::Stream)
  end

  it 'can create a Mua::State::Context' do
    context = MockStream.context('example')

    expect(context).to be_kind_of(Mua::State::Context)
    expect(context.input).to be_kind_of(Async::IO::Stream)
  end

  it 'can create a Mua::State::Context and StringIO pair' do
    context, io = MockStream.context_io('example')

    expect(context).to be_kind_of(Mua::State::Context)
    expect(context.input).to be_kind_of(Async::IO::Stream)
    expect(io).to be_kind_of(StringIO)
  end
end
