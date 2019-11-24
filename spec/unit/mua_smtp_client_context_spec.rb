RSpec.describe Mua::SMTP::Client::Context, type: :reactor do
  it 'is a Mua::State::Context' do
    expect(Mua::SMTP::Client::Context.ancestors).to include(Mua::State::Context)
  end

  it 'has properties with defaults' do
    context = Mua::SMTP::Client::Context.new

    expect(context.username).to be(nil)
    expect(context.password).to be(nil)
    expect(context.remote).to be(nil)
    expect(context.read_task).to be(nil)
    expect(context.features).to eq({ })
    expect(context.hostname).to eq('localhost')
    expect(context.protocol).to be(:smtp)
    expect(context).to be_tls_requested
    expect(context).to_not be_tls_required
    expect(context).to_not be_proxy
    expect(context.timeout).to be(Mua::Constants::TIMEOUT_DEFAULT)
    expect(context.message_queue).to eq([ ])
    expect(context.message).to be(nil)
    expect(context).to_not be_close_requested
  end

  it 'allows writing to properties' do
    context = Mua::SMTP::Client::Context.new
    message = Mua::SMTP::Message.new(
      mail_from: 'mail-from@example.org',
      rcpt_to: 'rcpt-to@example.org',
      data: 'From: Demo'
    )

    context.username = 'user'
    context.password = 'pass'
    context.remote = 'mail.example.net'
    context.read_task = reactor
    context.features[:max_size] = 1024
    context.hostname = 'mta.example.org'
    context.protocol = :esmtp
    context.auth_required!
    context.tls_requested = false
    context.tls_required!
    context.proxy!
    context.timeout = 999
    context.message_queue << message
    context.message = message
    context.close_requested!

    expect(context.username).to eq('user')
    expect(context.password).to eq('pass')
    expect(context.remote).to eq('mail.example.net')
    expect(context.read_task).to be(reactor)
    expect(context.features).to eq(max_size: 1024)
    expect(context.hostname).to eq('mta.example.org')
    expect(context.protocol).to be(:esmtp)
    expect(context).to be_auth_required
    expect(context).to_not be_tls_requested
    expect(context).to be_tls_required
    expect(context).to be_proxy
    expect(context.timeout).to eq(999)
    expect(context.message_queue).to eq([ message ])
    expect(context.message).to be(message)
    expect(context).to be_close_requested
  end

  context 'has extensions' do
    it 'to queue up messages' do
      context = Mua::SMTP::Client::Context.new
      message = Mua::SMTP::Message.new(
        mail_from: 'mail-from@example.org',
        rcpt_to: 'rcpt-to@example.org',
        data: 'From: Demo'
      )

      context.deliver!(message)
      expect(context.message_queue).to eq([ message ])
    end
  end
end
