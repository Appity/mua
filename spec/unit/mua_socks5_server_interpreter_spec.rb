RSpec.describe Mua::SOCKS5::Server::Interpreter, type: :reactor, timeout: 5 do
  it 'can negotiate a basic SOCKS5 IPv4 connection' do
    MockStream.context_writable_io(Mua::SOCKS5::Server::Context) do |context, io|
      expect(context).to be_kind_of(Mua::SOCKS5::Server::Context)

      interpreter = Mua::SOCKS5::Server::Interpreter.new(context)

      expect(context.state).to eq(:initialize)

      reactor.async do
        interpreter.run do |c, s, *ev|
          p([ s.name, ev ]) if (ENV['DEBUG'])
        end
      end

      reactor.async do |task|
        io.write([ 5, 2, 0, 1 ].pack('C4'))
        io.flush

        read = io.read_exactly(2).unpack('CC')

        expect(read).to eq([ 5, 0 ])

        io.write([ 5, 1, 1, 127, 0, 0, 1, 32020 ].pack('CCxCC4n'))
        io.flush


        read = io.read_exactly(10).unpack('CCxCC4n')

        # Should return connection refused
        expect(read).to eq([ 5, 5, 1, 127, 0, 0, 1, 32020 ])

        task.sleep(0.05)
      end.wait

      expect(context.state).to eq(:connect)
    end
  end
end
