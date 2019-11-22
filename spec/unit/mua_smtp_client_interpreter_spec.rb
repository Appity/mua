require_relative '../support/smtp_delegate'
require_relative '../support/mock_stream'

RSpec.describe Mua::SMTP::Client::Interpreter do
  Context = Mua::SMTP::Client::Context
  Interpreter = Mua::SMTP::Client::Interpreter.define

  it 'defines a context type' do
    expect(Interpreter.context).to be(Context)

    expect(Interpreter.new(nil).context).to be_kind_of(Context)
  end

  it 'starts out in the initailized state' do
    context = Interpreter.context.new

    expect(context.state).to eq(:initialize)
  end

  it 'supports standard SMTP connections using HELO' do
    MockStream.line_exchange(Interpreter) do |interpreter, context, io|
      context.hostname = 'example.test'

      io.puts("220 mail.example.com SMTP Example")

      response = io.gets

      expect(response).to eq('HELO example.test')
    end

    # expect(interpreter.state).to eq(:helo)
    # expect(delegate.read).to eq('HELO localhost.local')

    # io.write("250 mail.example.com Hello\r\n")
    # expect(interpreter.state).to eq(:ready)

    # interpreter.enter_state(:quit)

    # expect(interpreter.state).to eq(:quit)
    # expect(delegate.read).to eq('QUIT')
    
    # io.write("221 mail.example.com closing connection\r\n")

    # expect(delegate).to be_closed
  end

  it 'can send mail using DATA' do
    delegate = SMTPDelegate.new
    interpreter = Mua::SMTP::Client::Interpreter.new(delegate: delegate)

    expect(interpreter.state).to eq(:initialized)
    
    io.write("220 mail.example.com SMTP Example\r\n")

    expect(interpreter.state).to eq(:helo)
    expect(delegate.read).to eq('HELO localhost.local')

    io.write("250 mail.example.com Hello\r\n")
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
    
    io.write("250 OK\r\n")
    
    expect(interpreter.state).to eq(:rcpt_to)

    expect(delegate.read).to eq('RCPT TO:<to@example.com>')
    
    io.write("250 Accepted\r\n")
    
    expect(interpreter.state).to eq(:data)
    
    expect(delegate.read).to eq('DATA')

    io.write("354 Enter message, ending with \".\" on a line by itself\r\n")
    
    expect(interpreter.state).to eq(:sending)
    
    io.write("250 OK id=1PN95Q-00072L-Uw\r\n")
    
    expect(interpreter.state).to eq(:ready)
  end
  
  it 'identifies ESMTP support and authenticates with EHLO but can terminate early' do
    delegate = SMTPDelegate.new
    interpreter = Mua::SMTP::Client::Interpreter.new(delegate: delegate)

    expect(interpreter.state).to eq(:initialized)
    
    io.write("220 mail.example.com ESMTP Exim 4.63\r\n")

    expect(interpreter.state).to eq(:ehlo)
    expect(delegate.read).to eq('EHLO localhost.local')

    io.write("250-mail.example.com Hello\r\n")
    expect(interpreter.state).to eq(:ehlo)

    io.write("250-SIZE 52428800\r\n")
    expect(interpreter.state).to eq(:ehlo)

    io.write("250-PIPELINING\r\n")
    expect(interpreter.state).to eq(:ehlo)

    io.write("250-STARTTLS\r\n")
    expect(interpreter.state).to eq(:ehlo)
    
    interpreter.enter_state(:quit)

    expect(interpreter.state).to eq(:quit)
    expect(delegate.read).to eq('QUIT')
    
    io.write("221 mail.example.com closing connection\r\n")

    expect(interpreter.state).to eq(:terminated)
    expect(delegate).to be_closed
  end
  
  it 'can handle multi-line EHLO responses' do
    delegate = SMTPDelegate.new(use_tls: true)
    interpreter = Mua::SMTP::Client::Interpreter.new(delegate: delegate)

    expect(interpreter.state).to eq(:initialized)
    expect(delegate.protocol).to eq(:smtp)

    io.write("220-mail.example.com Hello ESMTP Example Server\r\n")
    expect(interpreter.state).to eq(:initialized)
    expect(delegate.protocol).to eq(:esmtp)

    io.write("220-This is a long notice that is posted here\r\n")
    expect(interpreter.state).to eq(:initialized)

    io.write("220-as some servers like to have a little chat\r\n")
    expect(interpreter.state).to eq(:initialized)

    io.write("220 with you before getting down to business.\r\n")

    expect(interpreter.state).to eq(:ehlo)
  end

  it 'will use TLS when advertised as a feature' do
    delegate = SMTPDelegate.new(use_tls: true)
    interpreter = Mua::SMTP::Client::Interpreter.new(delegate: delegate)
    
    expect(delegate).to be_use_tls
    expect(interpreter.state).to eq(:initialized)

    io.write("220 mail.example.com ESMTP Exim 4.63\r\n")
    expect(interpreter.state).to eq(:ehlo)
    expect(delegate.read).to eq('EHLO localhost.local')
    
    io.write("250-mail.example.com Hello\r\n")
    io.write("250-RANDOMCOMMAND\r\n")
    io.write("250-EXAMPLECOMMAND\r\n")
    io.write("250-SIZE 52428800\r\n")
    io.write("250-PIPELINING\r\n")
    io.write("250-STARTTLS\r\n")
    io.write("250 HELP\r\n")
    
    expect(delegate).to be_tls_support

    expect(interpreter.state).to eq(:starttls)
    expect(delegate.read).to eq('STARTTLS')
    expect(delegate).to_not be_started_tls
    
    io.write("220 TLS go ahead\r\n")
    expect(delegate).to be_started_tls
    
    expect(interpreter.state).to eq(:ehlo)
  end

  it 'will not use TLS unless advertised' do
    delegate = SMTPDelegate.new(use_tls: true)
    interpreter = Mua::SMTP::Client::Interpreter.new(delegate: delegate)

    io.write("220 mail.example.com ESMTP Exim 4.63\r\n")
    expect(delegate.read).to eq('EHLO localhost.local')
    
    io.write("250-mail.example.com Hello\r\n")
    io.write("250 HELP\r\n")
    
    expect(delegate).to_not be_started_tls

    expect(interpreter.state).to eq(:ready)
  end

  it 'will use plaintext authentication by default' do
    delegate = SMTPDelegate.new(username: 'tester@example.com', password: 'tester')
    interpreter = Mua::SMTP::Client::Interpreter.new(delegate: delegate)
    
    expect(delegate).to be_requires_authentication

    expect(interpreter.state).to eq(:initialized)

    io.write("220 mail.example.com SMTP Server 1.0\r\n")
    expect(delegate.read).to eq('HELO localhost.local')

    expect(interpreter.state).to eq(:helo)
    
    io.write("250-mail.example.com Hello\r\n")
    io.write("250 HELP\r\n")

    expect(delegate).to_not be_started_tls
    
    expect(interpreter.state).to eq(:auth)
    expect(delegate.read).to eq('AUTH PLAIN AHRlc3RlckBleGFtcGxlLmNvbQB0ZXN0ZXI=')
    
    io.write("235 Accepted\r\n")
    
    expect(interpreter.state).to eq(:ready)
  end

  it 'will use plaintext authentication by default with ESMTP' do
    delegate = SMTPDelegate.new(username: 'tester@example.com', password: 'tester')
    interpreter = Mua::SMTP::Client::Interpreter.new(delegate: delegate)

    io.write("220 mail.example.com ESMTP Exim 4.63\r\n")
    expect(delegate.read).to eq('EHLO localhost.local')
    
    io.write("250-mail.example.com Hello\r\n")
    io.write("250 HELP\r\n")
    
    expect(delegate).to_not be_started_tls

    expect(interpreter.state).to eq(:auth)
    expect(delegate.read).to eq('AUTH PLAIN AHRlc3RlckBleGFtcGxlLmNvbQB0ZXN0ZXI=')
    
    io.write("235 Accepted\r\n")
    
    expect(interpreter.state).to eq(:ready)
  end

  it 'can handle ESTMP auth rejections' do
    delegate = SMTPDelegate.new(username: 'tester@example.com', password: 'tester')
    interpreter = Mua::SMTP::Client::Interpreter.new(delegate: delegate)

    io.write("220 mx.google.com ESMTP\r\n")
    expect(delegate.read).to eq('EHLO localhost.local')
    
    io.write("250-mx.google.com at your service\r\n")
    io.write("250 HELP\r\n")

    expect(delegate).to_not be_started_tls

    expect(interpreter.state).to eq(:auth)
    expect(delegate.read).to eq('AUTH PLAIN AHRlc3RlckBleGFtcGxlLmNvbQB0ZXN0ZXI=')
    
    io.write("535-5.7.1 Username and Password not accepted. Learn more at\r\n")
    io.write("535 5.7.1 http://mail.google.com/support/bin/answer.py?answer=14257\r\n")
    
    expect(interpreter.error).to eq('5.7.1 Username and Password not accepted. Learn more at http://mail.google.com/support/bin/answer.py?answer=14257')

    expect(interpreter.state).to eq(:quit)
    
    io.write("221 2.0.0 closing connection\r\n")
    
    expect(interpreter.state).to eq(:terminated)
    expect(delegate).to be_closed
  end

  it 'can identify unexpected responses' do
    delegate = SMTPDelegate.new(username: 'tester@example.com', password: 'tester')
    interpreter = Mua::SMTP::Client::Interpreter.new(delegate: delegate)

    io.write("530 Go away\r\n")
    
    expect(interpreter.state).to eq(:terminated)
    expect(delegate).to be_closed
  end
end
