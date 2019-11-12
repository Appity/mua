class SMTPDelegate
  attr_accessor :options, :protocol, :active_message
  attr_accessor :tls_support
  
  def initialize(options = { })
    @sent = [ ]
    @options = options
    @protocol = :smtp
    @started_tls = false
    @tls_support = nil
    @closed = false
  end
  
  def hostname
    'localhost.local'
  end
  
  def requires_authentication?
    !!@options[:username]
  end
  
  def use_tls?
    !!@options[:use_tls]
  end
  
  def send_line(data  = '')
    @sent << data
  end
  
  def start_tls
    @started_tls = true
  end
  
  def started_tls?
    !!@started_tls
  end
  
  def tls_support?
    !!@tls_support
  end
  
  def close_connection
    @closed = true
  end
  
  def closed?
    !!@closed
  end
  
  def clear!
    @sent = [ ]
  end
  
  def size
    @sent.size
  end
  
  def read
    @sent.shift
  end
  
  def method_missing(*args)
  end
end

RSpec.describe Mua::SMTP::Client::Interpreter do
  it 'can split simple replies' do
    expect_mapping(
      '250 OK' => [ 250, 'OK' ],
      '250 Long message' => [ 250, 'Long message' ],
      'OK' => nil,
      '100-Example' => [ 100, 'Example', :continued ]
    ) do |reply|
      Mua::SMTP::Client::Interpreter.split_reply(reply)
    end
  end

  def test_parser
    interpreter = Mua::SMTP::Client::Interpreter.new
    
    expect_mapping(
      "250 OK\r\n" => [ 250, 'OK' ],
      "250 Long message\r\n" => [ 250, 'Long message' ],
      "OK\r\n" => nil,
      "100-Example\r\n" => [ 100, 'Example', :continued ],
      "100-Example" => nil
    ) do |reply|
      interpreter.parse(reply.dup)
    end
  end

  it 'can encode for DATA by avoiding single dot lines' do
    sample_data = "Line 1\r\nLine 2\r\n.\r\nLine 3\r\n.Line 4\r\n".freeze
    
    expect(Mua::SMTP::Client::Interpreter.encode_data(sample_data)).to eq("Line 1\r\nLine 2\r\n..\r\nLine 3\r\n..Line 4\r\n")
  end

  it 'can decode Base64-encoded content with Interpreter#base64' do
    expect_mapping(
      'example' => 'example',
      "\x7F" => "\x7F",
      nil => ''
    ) do |example|
      Mua::SMTP::Client::Interpreter.base64(example).unpack('m')[0]
    end
  end
  
  it '#encode_authentication can encode username/password pairs correctly' do
    expect_mapping(
      %w[ tester tester ] => 'AHRlc3RlcgB0ZXN0ZXI='
    ) do |username, password|
      Mua::SMTP::Client::Interpreter.encode_authentication(username, password)
    end
  end

  it 'starts out in the initailized state' do
    interpreter = Mua::SMTP::Client::Interpreter.new
    
    expect(interpreter.state).to eq(:initialized)
  end
  
  context 'SMTPDelegate' do
    it 'has simple defaults' do
      delegate = SMTPDelegate.new

      expect(delegate).to_not be_closed
      expect(delegate.read).to be(nil)
      expect(delegate.size).to eq(0)
    end

    it 'can have options set' do
      delegate = SMTPDelegate.new(use_tls: true)

      expect(delegate.use_tls?).to be(true)
      expect(delegate.requires_authentication?).to be(false)

      delegate = SMTPDelegate.new(username: 'test@example.com', password: 'tester')

      expect(delegate.use_tls?).to be(false)
      expect(delegate.requires_authentication?).to be(true)
    end
  end

  it 'supports standard SMTP connections using HELO' do
    delegate = SMTPDelegate.new
    interpreter = Mua::SMTP::Client::Interpreter.new(delegate: delegate)

    expect(interpreter.state).to eq(:initialized)
    
    interpreter.process("220 mail.example.com SMTP Example\r\n")

    expect(interpreter.state).to eq(:helo)
    expect(delegate.read).to eq('HELO localhost.local')

    interpreter.process("250 mail.example.com Hello\r\n")
    expect(interpreter.state).to eq(:ready)

    interpreter.enter_state(:quit)

    expect(interpreter.state).to eq(:quit)
    expect(delegate.read).to eq('QUIT')
    
    interpreter.process("221 mail.example.com closing connection\r\n")

    expect(delegate).to be_closed
  end

  it 'can send mail using DATA' do
    delegate = SMTPDelegate.new
    interpreter = Mua::SMTP::Client::Interpreter.new(delegate: delegate)

    expect(interpreter.state).to eq(:initialized)
    
    interpreter.process("220 mail.example.com SMTP Example\r\n")

    expect(interpreter.state).to eq(:helo)
    expect(delegate.read).to eq('HELO localhost.local')

    interpreter.process("250 mail.example.com Hello\r\n")
    expect(interpreter.state).to eq(:ready)

    delegate.active_message = {
      from: 'from@example.com',
      to: 'to@example.com',
      data: "Subject: Test Message\r\n\r\nThis is a message!\r\n"
    }
    
    # Force into send state
    interpreter.enter_state(:send)
    
    expect(interpreter.state).to eq(:mail_from)
    expect(delegate.read).to eq('MAIL FROM:<from@example.com>')
    
    interpreter.process("250 OK\r\n")
    
    expect(interpreter.state).to eq(:rcpt_to)

    expect(delegate.read).to eq('RCPT TO:<to@example.com>')
    
    interpreter.process("250 Accepted\r\n")
    
    expect(interpreter.state).to eq(:data)
    
    expect(delegate.read).to eq('DATA')

    interpreter.process("354 Enter message, ending with \".\" on a line by itself\r\n")
    
    expect(interpreter.state).to eq(:sending)
    
    interpreter.process("250 OK id=1PN95Q-00072L-Uw\r\n")
    
    expect(interpreter.state).to eq(:ready)
  end
  
  it 'identifies ESMTP support and authenticates with EHLO but can terminate early' do
    delegate = SMTPDelegate.new
    interpreter = Mua::SMTP::Client::Interpreter.new(delegate: delegate)

    expect(interpreter.state).to eq(:initialized)
    
    interpreter.process("220 mail.example.com ESMTP Exim 4.63\r\n")

    expect(interpreter.state).to eq(:ehlo)
    expect(delegate.read).to eq('EHLO localhost.local')

    interpreter.process("250-mail.example.com Hello\r\n")
    expect(interpreter.state).to eq(:ehlo)

    interpreter.process("250-SIZE 52428800\r\n")
    expect(interpreter.state).to eq(:ehlo)

    interpreter.process("250-PIPELINING\r\n")
    expect(interpreter.state).to eq(:ehlo)

    interpreter.process("250-STARTTLS\r\n")
    expect(interpreter.state).to eq(:ehlo)
    
    interpreter.enter_state(:quit)

    expect(interpreter.state).to eq(:quit)
    expect(delegate.read).to eq('QUIT')
    
    interpreter.process("221 mail.example.com closing connection\r\n")

    expect(interpreter.state).to eq(:terminated)
    expect(delegate).to be_closed
  end
  
  it 'can handle multi-line EHLO responses' do
    delegate = SMTPDelegate.new(use_tls: true)
    interpreter = Mua::SMTP::Client::Interpreter.new(delegate: delegate)

    expect(interpreter.state).to eq(:initialized)
    expect(delegate.protocol).to eq(:smtp)

    interpreter.process("220-mail.example.com Hello ESMTP Example Server\r\n")
    expect(interpreter.state).to eq(:initialized)
    expect(delegate.protocol).to eq(:esmtp)

    interpreter.process("220-This is a long notice that is posted here\r\n")
    expect(interpreter.state).to eq(:initialized)

    interpreter.process("220-as some servers like to have a little chat\r\n")
    expect(interpreter.state).to eq(:initialized)

    interpreter.process("220 with you before getting down to business.\r\n")

    expect(interpreter.state).to eq(:ehlo)
  end

  it 'will use TLS when advertised as a feature' do
    delegate = SMTPDelegate.new(use_tls: true)
    interpreter = Mua::SMTP::Client::Interpreter.new(delegate: delegate)
    
    expect(delegate).to be_use_tls
    expect(interpreter.state).to eq(:initialized)

    interpreter.process("220 mail.example.com ESMTP Exim 4.63\r\n")
    expect(interpreter.state).to eq(:ehlo)
    expect(delegate.read).to eq('EHLO localhost.local')
    
    interpreter.process("250-mail.example.com Hello\r\n")
    interpreter.process("250-RANDOMCOMMAND\r\n")
    interpreter.process("250-EXAMPLECOMMAND\r\n")
    interpreter.process("250-SIZE 52428800\r\n")
    interpreter.process("250-PIPELINING\r\n")
    interpreter.process("250-STARTTLS\r\n")
    interpreter.process("250 HELP\r\n")
    
    expect(delegate).to be_tls_support

    expect(interpreter.state).to eq(:starttls)
    expect(delegate.read).to eq('STARTTLS')
    expect(delegate).to_not be_started_tls
    
    interpreter.process("220 TLS go ahead\r\n")
    expect(delegate).to be_started_tls
    
    expect(interpreter.state).to eq(:ehlo)
  end

  it 'will not use TLS unless advertised' do
    delegate = SMTPDelegate.new(use_tls: true)
    interpreter = Mua::SMTP::Client::Interpreter.new(delegate: delegate)

    interpreter.process("220 mail.example.com ESMTP Exim 4.63\r\n")
    expect(delegate.read).to eq('EHLO localhost.local')
    
    interpreter.process("250-mail.example.com Hello\r\n")
    interpreter.process("250 HELP\r\n")
    
    expect(delegate).to_not be_started_tls

    expect(interpreter.state).to eq(:ready)
  end

  it 'will use plaintext authentication by default' do
    delegate = SMTPDelegate.new(username: 'tester@example.com', password: 'tester')
    interpreter = Mua::SMTP::Client::Interpreter.new(delegate: delegate)
    
    expect(delegate).to be_requires_authentication

    expect(interpreter.state).to eq(:initialized)

    interpreter.process("220 mail.example.com SMTP Server 1.0\r\n")
    expect(delegate.read).to eq('HELO localhost.local')

    expect(interpreter.state).to eq(:helo)
    
    interpreter.process("250-mail.example.com Hello\r\n")
    interpreter.process("250 HELP\r\n")

    expect(delegate).to_not be_started_tls
    
    expect(interpreter.state).to eq(:auth)
    expect(delegate.read).to eq('AUTH PLAIN AHRlc3RlckBleGFtcGxlLmNvbQB0ZXN0ZXI=')
    
    interpreter.process("235 Accepted\r\n")
    
    expect(interpreter.state).to eq(:ready)
  end

  it 'will use plaintext authentication by default with ESMTP' do
    delegate = SMTPDelegate.new(username: 'tester@example.com', password: 'tester')
    interpreter = Mua::SMTP::Client::Interpreter.new(delegate: delegate)

    interpreter.process("220 mail.example.com ESMTP Exim 4.63\r\n")
    expect(delegate.read).to eq('EHLO localhost.local')
    
    interpreter.process("250-mail.example.com Hello\r\n")
    interpreter.process("250 HELP\r\n")
    
    expect(delegate).to_not be_started_tls

    expect(interpreter.state).to eq(:auth)
    expect(delegate.read).to eq('AUTH PLAIN AHRlc3RlckBleGFtcGxlLmNvbQB0ZXN0ZXI=')
    
    interpreter.process("235 Accepted\r\n")
    
    expect(interpreter.state).to eq(:ready)
  end

  it 'can handle ESTMP auth rejections' do
    delegate = SMTPDelegate.new(username: 'tester@example.com', password: 'tester')
    interpreter = Mua::SMTP::Client::Interpreter.new(delegate: delegate)

    interpreter.process("220 mx.google.com ESMTP\r\n")
    expect(delegate.read).to eq('EHLO localhost.local')
    
    interpreter.process("250-mx.google.com at your service\r\n")
    interpreter.process("250 HELP\r\n")

    expect(delegate).to_not be_started_tls

    expect(interpreter.state).to eq(:auth)
    expect(delegate.read).to eq('AUTH PLAIN AHRlc3RlckBleGFtcGxlLmNvbQB0ZXN0ZXI=')
    
    interpreter.process("535-5.7.1 Username and Password not accepted. Learn more at\r\n")
    interpreter.process("535 5.7.1 http://mail.google.com/support/bin/answer.py?answer=14257\r\n")
    
    expect(interpreter.error).to eq('5.7.1 Username and Password not accepted. Learn more at http://mail.google.com/support/bin/answer.py?answer=14257')

    expect(interpreter.state).to eq(:quit)
    
    interpreter.process("221 2.0.0 closing connection\r\n")
    
    expect(interpreter.state).to eq(:terminated)
    expect(delegate).to be_closed
  end

  it 'can identify unexpected responses' do
    delegate = SMTPDelegate.new(username: 'tester@example.com', password: 'tester')
    interpreter = Mua::SMTP::Client::Interpreter.new(delegate: delegate)

    interpreter.process("530 Go away\r\n")
    
    expect(interpreter.state).to eq(:terminated)
    expect(delegate).to be_closed
  end
end
