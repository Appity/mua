RSpec.describe Mua::SMTP::Client::Context do
  it 'is a Mua::State::Context' do
    expect(Mua::SMTP::Client::Context.ancestors).to include(Mua::State::Context)
  end

  it 'has properties with defaults' do
    context = Mua::SMTP::Client::Context.new

    expect(context.username).to be(nil)
    expect(context.password).to be(nil)
    expect(context.remote).to be(nil)
    expect(context.hostname).to be('localhost')
    expect(context.protocol).to be(:smtp)
    expect(context.auth_support?).to be(false)
    expect(context.auth_required?).to be(false)
    expect(context.tls?).to be(false)
    expect(context.proxy?).to be(false)
    expect(context.timeout).to be(Mua::Constants::TIMEOUT_DEFAULT)
  end
end
