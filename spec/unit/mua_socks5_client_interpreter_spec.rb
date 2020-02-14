RSpec.describe Mua::SOCKS5::Client::Interpreter, type: :reactor, timeout: 5 do
  it 'can connect through a SOCKS5 server' do
    MockStream.context_writable_io(Mua::Client::Context) do |context, io|
      expect(context).to be_kind_of(Mua::Client::Context)

      context.smtp_host = '127.0.0.1'
      context.smtp_port = 1025
      context.proxy_host = '127.0.0.1'
      context.proxy_port = 1080

      interpreter = Mua::SOCKS5::Client::Interpreter.new(context)

      expect(context.state).to eq(:initialize)

      reactor.async do
        interpreter.run do |c, s, *ev|
          p([ s.name, ev ]) if (ENV['DEBUG'])
        end
      end.wait

      reactor.async do
        read = io.read_exactly(3).unpack('C3')

        expect(read).to eq([ 5, 1, 0 ])

        io.write([ 5, 0 ].pack('C2'))
        io.flush

        read = io.read_exactly(4).unpack('CCxC')

        expect(read).to eq([ 5, 1, 1 ])

        read = io.read_exactly(6).unpack('C4n')

        expect(read).to eq([ 127, 0, 0, 1, 1025 ])

        io.write([ 5, 0, 1, 127, 0, 0, 1, 32000 ].pack('CCxCC4n'))
        io.flush
      end.wait
    end
  end

  it 'can handle a variety of SOCKS5 general server failure issues' do
    [ 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07 ].each do |reply_code|
      MockStream.context_writable_io(Mua::Client::Context) do |context, io|
        expect(context).to be_kind_of(Mua::Client::Context)

        context.smtp_host = '127.0.0.1'
        context.smtp_port = 1025
        context.proxy_host = '127.0.0.1'
        context.proxy_port = 1080

        interpreter = Mua::SOCKS5::Client::Interpreter.new(context)

        expect(context.state).to eq(:initialize)

        reactor.async do
          interpreter.run do |c, s, *ev|
            p([ s.name, ev ]) if (ENV['DEBUG'])
          end
        end.wait

        reactor.async do |task|
          read = io.read_exactly(3).unpack('C3')

          expect(read).to eq([ 5, 1, 0 ])

          io.write([ 5, 0 ].pack('C2'))
          io.flush

          read = io.read_exactly(4).unpack('CCxC')

          expect(read).to eq([ 5, 1, 1 ])

          read = io.read_exactly(6).unpack('C4n')

          expect(read).to eq([ 127, 0, 0, 1, 1025 ])

          io.write([ 5, reply_code, 1, 127, 0, 0, 1, 1025 ].pack('CCxCC4n'))
          io.flush

          task.sleep(0.05)
        end.wait

        expect(context.reply_code).to eq('SOCKS5_ERR%d' % reply_code)
      end
    end
  end

  it 'can handle a premature disconnection' do
    MockStream.context_writable_io(Mua::Client::Context) do |context, io|
      expect(context).to be_kind_of(Mua::Client::Context)

      context.smtp_host = '127.0.0.1'
      context.smtp_port = 1025
      context.proxy_host = '127.0.0.1'
      context.proxy_port = 1080

      interpreter = Mua::SOCKS5::Client::Interpreter.new(context)

      expect(context.state).to eq(:initialize)

      reactor.async do
        interpreter.run do |c, s, *ev|
          p([ s.name, ev ]) if (ENV['DEBUG'])
        end
      end.wait

      reactor.async do |task|
        read = io.read_exactly(3).unpack('C3')

        expect(read).to eq([ 5, 1, 0 ])

        io.write([ 5, 0 ].pack('C2'))
        io.flush

        io.close

        task.sleep(0.05)
      end.wait

      expect(context.reply_code).to eq('ERRNO_EPIPE')
    end
  end
end
