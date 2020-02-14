require_relative 'mock_stream'

RSpec.describe MockStream, type: :reactor, timeout: 1 do
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

  context 'can create a Mua::State::Context and read/writable IO pair' do
    it 'returns a context an io object for writing' do
      MockStream.context_writable_io do |context, io|
        expect(context).to be_kind_of(Mua::State::Context)

        expect(context.input).to be_kind_of(Async::IO::Stream)

        expect(io).to be_kind_of(Async::IO::Stream)
      end
    end

    it 'which can be used for sequential write, read operations' do
      MockStream.context_writable_io do |context, io|
        io.puts('example')

        expect(context.input.gets.chomp).to eq('example')

        io.write('1234')
        io.flush

        expect(context.input.read_exactly(4)).to eq('1234')

        context.input.write('4321')
        context.input.flush

        expect(io.read_exactly(4)).to eq('4321')
      end
    end

    it 'which can be used in an async out-of-order' do
      MockStream.context_writable_io do |context, io|
        reactor.async do
          context.input.write('test')
          context.input.flush
        end

        reactor.async do
          read = io.read_exactly(4)

          expect(read).to eq('test')
        end
      end
    end
  end
end
