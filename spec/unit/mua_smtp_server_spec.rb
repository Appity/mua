RSpec.describe Mua::SMTP::Server, type: :reactor, timeout: 1 do
  it 'can open up a server that accepts incoming SMTP connections' do
    server = Mua::SMTP::Server.new(
      port: 8025 # REFACTOR: Should allow binding to random port
    )

    expect(server)

    count = 10
    clients = count.times.map do
      Mua::SMTP::Client.new(
        smtp_host: 'localhost',
        smtp_port: 8025
      ) do |c,s,*ev|
        puts '%s> %s %s' % [ c.remote_addr, s.name, ev.inspect ] if (ENV['DEBUG'])
      end
    end

    reactor.sleep(0.1)

    expect(clients.map(&:state)).to eq([ :ready ] * count)

    clients.each(&:quit!)
  end
end
