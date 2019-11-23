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
    expect(context.hostname).to eq('localhost')
    expect(context.protocol).to be(:smtp)
    expect(context).to_not be_auth_support
    expect(context).to_not be_auth_required
    expect(context).to_not be_tls
    expect(context).to_not be_tls_supported
    expect(context).to_not be_proxy
    expect(context.timeout).to be(Mua::Constants::TIMEOUT_DEFAULT)
    expect(context.delivery_queue).to eq([ ])
    expect(context.delivery).to be(nil)
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
    context.hostname = 'mta.example.org'
    context.protocol = :esmtp
    context.auth_support!
    context.auth_required!
    context.tls!
    context.tls_supported!
    context.proxy!
    context.timeout = 999
    context.delivery_queue << message
    context.delivery = message

    expect(context.username).to eq('user')
    expect(context.password).to eq('pass')
    expect(context.remote).to eq('mail.example.net')
    expect(context.read_task).to be(reactor)
    expect(context.hostname).to eq('mta.example.org')
    expect(context.protocol).to be(:esmtp)
    expect(context).to be_auth_support
    expect(context).to be_auth_required
    expect(context).to be_tls
    expect(context).to be_tls_supported
    expect(context).to be_proxy
    expect(context.timeout).to eq(999)
    expect(context.delivery_queue).to eq([ message ])
    expect(context.delivery).to be(message)
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
      expect(context.delivery_queue).to eq([ message ])
    end
  end
end
