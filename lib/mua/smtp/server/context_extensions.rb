require 'logger'

module Mua::SMTP::Server::ContextExtensions
  def log(channel, *lines, severity: nil)
    return unless (defined?(@logger) and @logger)

    level ||= Logger::DEBUG

    lines.each do |line|
      @logger.add(level, '%s> %s' % [ channel, line ])
    end
  end

  def reset_transaction!
    self.message = Mua::SMTP::Message.new
  end

  def banner
    @banner ||=
      '220 %s Mua %s Server Ready' % [
        self.hostname,
        self.protocol.to_s.upcase
      ]
  end

  def banner=(str)
    @banner = str
  end

  def tls_engaged?
    self.input.is_a?(Async::IO::SSLSocket)
  end

  def tls_configured?
    self.tls_key_path and self.tls_cert_path
  end

  def valid_hostname?(hostname)
    true
  end

  def will_accept_auth?(username, password)
    [ true, '235 Authentication successful' ]
  end

  def will_accept_connection?(hostname, context)
    [ true, '250 Accepted' ]
  end

  def will_accept_sender?(sender)
    [ true, '250 Accepted' ]
  end

  def will_accept_recipient?(recipient)
    [ true, '250 Accepted' ]
  end

  def will_accept_transaction?(transaction)
    [ true, '250 Accepted' ]
  end

  def receive_transaction(message)
    self.messages << message

    [ true, '250 Accepted' ]
  end

  def close!
    self.input.flush
    self.input.close_write

  rescue Errno::ENOTCONN, IOError
    # Connection is already closed, so this can be ignored.
  end

  def tls_cert
    # FIX: Rescue if these files don't exist
    # FIX: Verify this certificate is still valid, warn if expired
    @tls_cert ||= OpenSSL::X509::Certificate.new(File.read(self.tls_cert_path))
  end

  def tls_key
    # FIX: Rescue if these files don't exist
    # FIX: Verify this is a private key
    @tls_key ||= OpenSSL::PKey.read(File.read(self.tls_key_path))
  end

  def starttls!
    @tls_context = OpenSSL::SSL::SSLContext.new.tap do |tls|
      # FIX: Verify key matches certificate
      tls.cert = self.tls_cert
      tls.key = self.tls_key
    end

    self.input.flush
    io = self.input.io
    timeout = io.timeout

    tls_socket = Async::IO::SSLSocket.new(io, @tls_context)
    tls_socket.accept

    tls_socket.wait

    yield(tls_socket) if (block_given?)

    self.input = Async::IO::Stream.new(tls_socket)
    self.input.io.timeout = timeout

    true

  rescue OpenSSL::SSL::SSLError => e
    self.event!(self, self.state, error: '[%s] %s' % [ e.class, e.to_s ])

    self.close!
    self.terminated!

    self.transition!(state: :finished)
  end

  def authenticated?
    !!self.authenticated
  end

  def authenticate!(username, password)
    # REFACTOR: This has a lot of duplication
    accept, reply, authenticated_as = self.will_accept_auth?(username, password)

    if (accept)
      self.reply(reply || '235 Authentication successful')

      self.authenticated_as = authenticated_as || username

      self.transition!(state: :ready)
    else
      self.reply(reply || '535 Authentication failed')

      self.transition!(state: :ready)
    end
  end
end
