RSpec.describe Mua::SMTP::Message, timeout: 5 do
  it 'has defaults' do
    message = Mua::SMTP::Message.new

    expect(message.mail_from).to be(nil)
    expect(message.rcpt_to).to eq([ ])
    expect(message.data).to eq('')
    expect(message).to_not be_test
    expect(message).to be_queued
    expect(message.state).to eq(:queued)
    expect(message.reply_code).to be(nil)
    expect(message.reply_message).to be(nil)
    expect(message.remote_ip).to be(nil)
    expect(message.auth_username).to be(nil)
  end

  it 'takes Symbol-keyed arguments' do
    message = Mua::SMTP::Message.new(
      id: 'fea199da483c@mta.example.org',
      mail_from: 'mail-from@example.org',
      rcpt_to: 'rcpt-to@example.org',
      data: 'Demo: true',
      test: 'very yes',
      state: 'failed',
      remote_ip: '127.0.0.1',
      auth_username: 'user@example.org'
    )

    expect(message.id).to eq('fea199da483c@mta.example.org')
    expect(message.mail_from).to eq('mail-from@example.org')
    expect(message.rcpt_to).to eq(%w[ rcpt-to@example.org ])
    expect(message.data).to eq('Demo: true')
    expect(message).to be_test
    expect(message).to be_failed
    expect(message.state).to eq(:failed)
    expect(message.remote_ip).to eq('127.0.0.1')
    expect(message.auth_username).to eq('user@example.org')
  end

  it 'takes String-keyed arguments' do
    message = Mua::SMTP::Message.new(
      'mail_from' => 'mail-from@example.org',
      'rcpt_to' => %w[ rcpt-to@example.org rcpt-to@example.net ],
      'data' => 'Demo: true',
      'test' => 'very yes',
      'state' => 'failed',
      'remote_ip' => '127.0.0.1',
      'auth_username' => 'user@example.org'
    )

    expect(message.mail_from).to eq('mail-from@example.org')
    expect(message.rcpt_to).to eq(%w[ rcpt-to@example.org rcpt-to@example.net ])
    expect(message.data).to eq('Demo: true')
    expect(message).to be_test
    expect(message).to be_failed
    expect(message.remote_ip).to eq('127.0.0.1')
    expect(message.auth_username).to eq('user@example.org')
  end

  it 'can be set to different states' do
    message = Mua::SMTP::Message.new

    states = Mua::SMTP::Message.states

    states.each do |state|
      message.state = state

      # Only one state is true, the rest are false
      states.each do |s|
        expect(message.send(:"#{s}?")).to eq(s == state)
      end
    end
  end
  
  it 'can be updated with a reply code/message' do
    message = Mua::SMTP::Message.new

    message.reply_code = '250'
    message.reply_message = 'We got it'

    expect(message.reply_code).to eq(250)
    expect(message.reply_message).to eq('We got it')
  end

  it 'can iterate over recipients' do
    message = Mua::SMTP::Message.new(
      rcpt_to: %w[
        r1@example.org
        r2@example.org
        r3@example.org
      ]
    )

    iterator = message.rcpt_to_iterator

    expect(iterator).to be_kind_of(Enumerator)

    expect(iterator.next).to eq('r1@example.org')
    expect(iterator.next).to eq('r2@example.org')
    expect(iterator.next).to eq('r3@example.org')
    expect { iterator.next }.to raise_exception(StopIteration)
  end
end
