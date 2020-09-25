module Mua::SMTP::Server::ContextExtensions
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

  def log(channel, *args)
    # FIX: Log stuff?
  end

  def valid_hostname?(hostname)
    true
  end

  def will_accept_auth?(username, password)
    [ true, '250 Accepted' ]
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

  rescue Errno::ENOTCONN
    # Connection is already closed, so this can be ignored.
  end

  def starttls!
    @tls_context = OpenSSL::SSL::SSLContext.new

    # FIX: Rescue if these things don't exist
    # REFACTOR: Maybe want to have the key pre-loaded, avoid paths
    cert = OpenSSL::X509::Certificate.new(File.read(self.tls_cert_path))
    key = OpenSSL::PKey.read(File.read(self.tls_key_path))

    @tls_context.add_certificate(cert, key)

    io = self.input.io
    timeout, io.timeout = io.timeout, nil

    tls_socket = Async::IO::SSLSocket.connect(io, @tls_context)
    yield(tls_socket) if (block_given?)

    self.input = Async::IO::Stream.new(tls_socket)

    true

  rescue OpenSSL::SSL::SSLError
    self.close!

    false
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
