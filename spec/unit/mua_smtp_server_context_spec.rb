RSpec.describe Mua::SMTP::Server::Context do
  it 'has defaults' do
    context = Mua::SMTP::Server::Context.new

    expect(context.read_task).to be(nil)
    expect(context.message).to be(nil)
    expect(context.helo_hostname).to be(nil)
    expect(context.smtp_username).to be(nil)
    expect(context.smtp_password).to be(nil)
    expect(context.tls_key_path).to be(nil)
    expect(context.tls_cert_path).to be(nil)
    expect(context.local_ip).to be(nil)
    expect(context.local_port).to be(nil)
    expect(context.remote_ip).to be(nil)
    expect(context.remote_port).to be(nil)
    expect(context.id).to be_kind_of(String)
    expect(context.connected_at).to be_kind_of(Time)
    expect(context.hostname).to eq('localhost')
    expect(context.smtp_timeout).to be_kind_of(Integer)
    expect(context.protocol).to be(:esmtp)
    expect(context.read_task).to be(nil)
    expect(context).to_not be_tls_initial
    expect(context).to_not be_tls_advertise
    expect(context).to_not be_tls_required
    expect(context.messages).to eq([ ])
  end
end
