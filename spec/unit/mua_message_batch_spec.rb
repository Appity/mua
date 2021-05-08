RSpec.describe Mua::Message::Batch, type: :reactor, timeout: 5 do
  context 'can be constructed' do
    it 'with defaults' do
      batch = Mua::Message::Batch.new

      expect(batch.length).to eq(0)
      expect(batch.processed_length).to eq(0)
      expect(batch.queue_length).to eq(0)
      expect(batch.size).to eq(0)
      expect(batch.processed_size).to eq(0)
      expect(batch.queue_size).to eq(0)

      expect(batch).to be_empty
      expect(batch).to be_queue_empty
      expect(batch).to be_processed_empty
      expect(batch).to_not be_any

      expect(batch).to_not be_closed
    end

    it 'with messages' do
      batch = Mua::Message::Batch.new([
        {
          mail_from: 'test@example.com',
          rcpt_to: %w[ r1@example.net ]
        },
        {
          mail_from: 'test@example.com',
          rcpt_to: %w[ r2@example.net ]
        }
      ])

      expect(batch.length).to eq(2)
      expect(batch.queue_length).to eq(2)
      expect(batch.processed_length).to eq(0)
      expect(batch.size).to eq(2)
      expect(batch.queue_size).to eq(2)

      expect(batch).to_not be_empty
      expect(batch).to_not be_queue_empty
      expect(batch).to be_processed_empty
      expect(batch).to be_any

      expect(batch.any?(&:delivered?)).to be(false)

      expect(batch).to be_closed
    end
  end

  it 'can report on delivery results' do
    batch = Mua::Message::Batch.new
  end

  context 'has a queue' do
    it 'that can be cycled through' do
      size = 100

      batch = Mua::Message::Batch.new(
        size.times.map do |i|
          {
            mail_from: 'test@example.com',
            rcpt_to: [ '%02d@example.org' % i ]
          }
        end
      )

      expect(batch).to be_closed

      expect(batch.length).to eq(size)
      expect(batch.queue_length).to eq(size)

      messages = [ ]
      called = false

      batch.each do |message|
        called = true
        messages << message
      end

      expect(called).to be(true)

      expect(messages.length).to eq(size)
    end

    it 'that can be stepped through' do
      size = 100

      batch = Mua::Message::Batch.new(
        size.times.map do |i|
          {
            mail_from: 'test@example.com',
            rcpt_to: [ '%02d@example.org' % i ]
          }
        end
      )

      expect(batch).to be_closed

      expect(batch.length).to eq(size)
      expect(batch.queue_length).to eq(size)

      messages = size.times.map do
        batch.next
      end

      expect(messages.length).to eq(size)
      expect(messages.map(&:id)).to eq(batch.message_ids)

      void = size.times.map do
        batch.next
      end

      expect(void).to eq([ nil ] * size)
    end

    it 'that waits until an entry is provided' do
      batch = Mua::Message::Batch.new

      expect(batch).to_not be_closed

      message = nil
      task = Async do
        message = batch.next
      end

      expect(message).to be(nil)

      queued = Mua::Message.new

      batch << queued

      task.wait

      expect(message).to be(queued)
    end

    it 'that allows singular requeues via next with a block' do
      batch = Mua::Message::Batch.new

      expect(batch).to_not be_closed

      message = nil
      task = Async do
        20.times do
          batch.next do |m|
            m.requeue!
          end
        end

        batch.next do |m|
          message = m
        end
      end

      expect(message).to be(nil)

      queued = Mua::Message.new

      batch << queued

      task.wait

      expect(message).to be(queued)
    end

    it 'that allows retries' do
      size = 50

      batch = Mua::Message::Batch.new(
        size.times.map do |i|
          {
            mail_from: 'test@example.com',
            rcpt_to: [ '%02d@example.org' % i ]
          }
        end
      )

      expect(batch).to be_closed

      expect(batch.length).to eq(size)
      expect(batch.queue_length).to eq(size)

      messages = [ ]

      batch.each do |message|
        if (message.delivery_results.any?)
          message.delivered!(result_code: 'SMTP_250')
          messages << message
        else
          message.retry!(result_code: 'SMTP_550')
          message.requeue!
        end
      end

      expect(messages.length).to eq(size)
      expect(messages.all?(&:delivered?))
      expect(messages.map { |m| m.delivery_results.map(&:state) }).to eq([ [ :retry, :delivered ] ] * size)

      expect(batch.processed_length).to eq(size)
      expect(batch.message_report).to eq(delivered: size)
    end
  end
end
