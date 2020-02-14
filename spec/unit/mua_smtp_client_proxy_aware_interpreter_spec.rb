RSpec.describe Mua::SMTP::Client::ProxyAwareInterpreter, type: :reactor, timeout: 1 do
  it 'can directly connect to an SMTP service' do
    context, io = MockStream.context_writable_io(Mua::Client::Context)

    expect(context).to be_kind_of(Mua::Client::Context)

    context.smtp_host = '127.0.0.1'
    context.smtp_port = 1025
    context.proxy_host = '127.0.0.1'
    context.proxy_port = 1080

    interpreter = Mua::SMTP::Client::ProxyAwareInterpreter.new(context)

    expect(context.state).to eq(:initialize)

    expect(context.input).to_not be_eof

    reactor.async do |task|
      task.async do
        read = io.read_exactly(3).unpack('C2')

        expect(read).to eq([ 5, 1, 0 ])

        io.write(%w[ 0500 ].pack('H*'))
        io.flush
      end

      task.async do
        interpreter.run
      end
    end
  end

  it 'can connect through a proxy to an SMTP service' do
  end
end
