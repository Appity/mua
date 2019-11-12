require_relative 'smtp_delegate'

RSpec.describe SMTPDelegate do
  it 'has simple defaults' do
    delegate = SMTPDelegate.new

    expect(delegate).to_not be_closed
    expect(delegate.read).to be(nil)
    expect(delegate.size).to eq(0)
  end

  it 'has a default hostname' do
    delegate = SMTPDelegate.new

    expect(delegate.hostname).to eq('localhost.local')
  end

  it 'has a customizable hostname' do
    delegate = SMTPDelegate.new(hostname: 'example.test')

    expect(delegate.hostname).to eq('example.test')
  end

  it 'has options to control TLS and AUTH' do
    delegate = SMTPDelegate.new(use_tls: true)

    expect(delegate.use_tls?).to be(true)
    expect(delegate.requires_authentication?).to be(false)

    delegate = SMTPDelegate.new(username: 'test@example.com', password: 'tester')

    expect(delegate.use_tls?).to be(false)
    expect(delegate.requires_authentication?).to be(true)
  end

  it 'can simulate engaging TLS mode' do
    delegate = SMTPDelegate.new(use_tls: true)

    expect(delegate).to_not be_started_tls

    delegate.start_tls

    expect(delegate).to be_started_tls
  end

  it 'can simulate closing the connection' do
    delegate = SMTPDelegate.new

    expect(delegate).to_not be_closed

    delegate.close

    expect(delegate).to be_closed
  end

  context 'send_line' do
    it 'supports printf placeholders using varargs' do
      delegate = SMTPDelegate.new

      delegate.send_line('These %d %s.', 2, 'tests')

      expect(delegate.read).to eq('These 2 tests.')
    end

    it 'preserves placeholders if no additional arguments are present' do
      delegate = SMTPDelegate.new

      delegate.send_line('10%s')

      expect(delegate.read).to eq('10%s')
    end
  end
end
