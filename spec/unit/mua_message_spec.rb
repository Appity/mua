RSpec.describe Mua::Message, type: :reactor, timeout: 5 do
  context 'can be constructed' do
    it 'with defaults' do
      message = Mua::Message.new

      expect(message.mail_from).to be(nil)
      expect(message.rcpt_to).to eq([ ])
      expect(message.data).to eq('')
      expect(message).to_not be_test
      expect(message).to be_queued
      expect(message.state).to eq(:queued)
      expect(message.result_code).to be(nil)
      expect(message.result_message).to be(nil)
      expect(message.remote_ip).to be(nil)
      expect(message.auth_username).to be(nil)
      expect(message.state).to eq(:queued)
    end

    it 'with kwargs' do
      message = Mua::Message.new(
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

    it 'with a hash using string keys' do
      message = Mua::Message.new({
        'mail_from' => 'mail-from@example.org',
        'rcpt_to' => %w[ rcpt-to@example.org rcpt-to@example.net ],
        'data' => 'Demo: true',
        'test' => 'very yes',
        'state' => 'failed',
        'remote_ip' => '127.0.0.1',
        'auth_username' => 'user@example.org'
      })

      expect(message.mail_from).to eq('mail-from@example.org')
      expect(message.rcpt_to).to eq(%w[ rcpt-to@example.org rcpt-to@example.net ])
      expect(message.data).to eq('Demo: true')
      expect(message).to be_test
      expect(message).to be_failed
      expect(message.remote_ip).to eq('127.0.0.1')
      expect(message.auth_username).to eq('user@example.org')
    end
  end

  it 'can be tested for equivalence' do
    message = Mua::Message.new

    expect(message.id)

    expect(message.eql?(message))
    expect(message.equal?(message))
    expect(message == message)

    array = [ message ]
    expect(array.include?(message)).to be(true)

    other = Mua::Message.new

    expect(message != other)
    expect(array.include?(other)).to be(false)
    expect(message.equal?(other)).to be(false)

    same_id = Mua::Message.new(id: message.id)

    expect(same_id.hash).to eq(message.hash)
    expect(message == same_id)
    expect(message.equal?(same_id)).to be(true)
    expect(array.include?(same_id)).to be(true)

    array.delete(same_id)
    expect(array).to be_empty
  end

  it 'can be set to different states' do
    message = Mua::Message.new

    states = Mua::Message.states

    states.each do |state|
      message.state = state

      # Only one state is true, the rest are false
      states.each do |s|
        expect(message.send(:"#{s}?")).to eq(s == state)
      end
    end
  end

  it 'can be set to a target state and automatically generate a delivery_result' do
    message = Mua::Message.new

    message.delivered!(
      result_code: 'SMTP_250',
      result_message: 'Received'
    )

    expect(message).to be_delivered
    expect(message.result_code).to eq('SMTP_250')
    expect(message.result_message).to eq('Received')

    expect(message.delivery_results.length).to eq(1)

    delivery_result = message.delivery_results[0]

    expect(delivery_result.result_code).to eq('SMTP_250')
    expect(delivery_result.result_message).to eq('Received')
  end

  it 'can be updated with a reply code/message' do
    message = Mua::Message.new

    message.result_code = 'SMTP_250'
    message.result_message = 'Received'

    expect(message.result_code).to eq('SMTP_250')
    expect(message.result_message).to eq('Received')
  end

  it 'can iterate over recipients' do
    message = Mua::Message.new(
      rcpt_to: %w[
        r1@example.org
        r2@example.org
        r3@example.org
      ]
    )

    iterator = message.each_rcpt

    expect(iterator).to be_kind_of(Enumerator)

    expect(iterator.next).to eq('r1@example.org')
    expect(iterator.next).to eq('r2@example.org')
    expect(iterator.next).to eq('r3@example.org')
    expect { iterator.next }.to raise_exception(StopIteration)
  end

  it 'can be marked as processed' do
    message = Mua::Message.new
    result = nil

    task = Async do
      result = message.wait
    end

    message.delivered!
    message.processed!

    task.wait

    expect(result).to be_kind_of(Mua::Message::DeliveryResult)
    expect(result.message).to be(message)
  end

  context 'from method' do
    it 'can pass through existing Message' do
      message = Mua::Message.new(
        mail_from: 'test@example.net',
        rcpt_to: %w[ dest@example.org ]
      )

      converted = Mua::Message.from(message)

      expect(converted.object_id).to eq(message.object_id)
    end

    context 'can create a Message' do
      it 'with string keys' do
        message = Mua::Message.from({
          'mail_from' => 'test@example.net',
          'rcpt_to' => %w[ dest@example.org ]
        })

        expect(message.mail_from).to eq('test@example.net')
        expect(message.rcpt_to).to eq(%w[ dest@example.org ])
      end

      it 'with symbol kwargs' do
        message = Mua::Message.from(
          mail_from: 'test@example.net',
          rcpt_to: %w[ dest@example.org ]
        )

        expect(message.mail_from).to eq('test@example.net')
        expect(message.rcpt_to).to eq(%w[ dest@example.org ])
      end
    end
  end
end
