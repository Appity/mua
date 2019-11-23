RSpec.describe Mua::SMTP::Message do
  it 'has defaults' do
    message = Mua::SMTP::Message.new

    expect(message.mail_from).to be(nil)
    expect(message.rcpt_to).to be(nil)
    expect(message.data).to be(nil)
    expect(message).to_not be_test
  end

  it 'takes Symbol-keyed arguments' do
    message = Mua::SMTP::Message.new(
      mail_from: 'mail-from@example.org',
      rcpt_to: 'rcpt-to@example.org',
      data: 'Demo: true',
      test: 'very yes'
    )

    expect(message.mail_from).to eq('mail-from@example.org')
    expect(message.rcpt_to).to eq('rcpt-to@example.org')
    expect(message.data).to eq('Demo: true')
    expect(message).to be_test
  end

  it 'takes String-keyed arguments' do
    message = Mua::SMTP::Message.new(
      'mail_from' => 'mail-from@example.org',
      'rcpt_to' => 'rcpt-to@example.org',
      'data' => 'Demo: true',
      'test' => 'very yes'
    )

    expect(message.mail_from).to eq('mail-from@example.org')
    expect(message.rcpt_to).to eq('rcpt-to@example.org')
    expect(message.data).to eq('Demo: true')
    expect(message).to be_test
  end
end
