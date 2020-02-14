RSpec.describe Mua::SMTP::Client::ProxyAwareInterpreter, type: :reactor, timeout: 1 do
  it 'can connect through a proxy to an SMTP service' do
    MockStream.context_writable_io(Mua::Client::Context) do |context, io|
      expect(context).to be_kind_of(Mua::Client::Context)

      context.smtp_host = '127.0.0.1'
      context.smtp_port = 1025
      context.proxy_host = '127.0.0.1'
      context.proxy_port = 1080

      interpreter = Mua::SMTP::Client::ProxyAwareInterpreter.new(context)

      expect(context.state).to eq(:initialize)

      reactor.async do
        interpreter.run do |c, s, *ev|
          p([ s.name, ev ]) if (ENV['DEBUG'])
        end
      end

      reactor.async do
        read = io.read_exactly(3).unpack('C3')

        expect(read).to eq([ 5, 1, 0 ])

        io.write([ 5, 0 ].pack('C2'))
        io.flush

        read = io.read_exactly(4).unpack('C4')

        expect(read).to eq([ 5, 1, 0, 1 ])

        read = io.read_exactly(6).unpack('C4n')

        expect(read).to eq([ 127, 0, 0, 1, 1025 ])

        io.write([ 5, 0, 0, 1, 127, 0, 0, 1, 32000 ].pack('CCCCC4n'))
        io.flush

        io.puts('220 localhost Mua ESMTP Server Ready')
        io.flush

        read = io.gets

        expect(read).to eq('EHLO localhost')
      end.wait
    end
  end

  it 'can directly connect to an SMTP service' do
    MockStream.context_writable_io(Mua::Client::Context) do |context, io|
      expect(context).to be_kind_of(Mua::Client::Context)

      context.smtp_host = '127.0.0.1'
      context.smtp_port = 1025

      interpreter = Mua::SMTP::Client::ProxyAwareInterpreter.new(context)

      expect(context.state).to eq(:initialize)

      reactor.async do
        interpreter.run do |c, s, *ev|
          p([ s.name, ev ]) if (ENV['DEBUG'])
        end
      end

      reactor.async do
        io.puts('220 localhost Mua ESMTP Server Ready')
        io.flush

        read = io.gets

        expect(read).to eq('EHLO localhost')
      end.wait
    end
  end
end
