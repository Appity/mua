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

  def remote_addr
    if (remote_port)
      '%s:%d' % [ remote_ip, remote_port ]
    else
      remote_ip
    end
  end

  def local_addr
    if (local_port)
      '%s:%d' % [ local_ip, local_port ]
    else
      local_ip
    end
  end

  def reset_ttl!
    @timeout_at = Time.now + self.connection_ttl
  end

  def connection_ttl
    10
  end

  def tls_configured?
    self.tls_key_path and self.tls_cert_path
  end
  
  def ttl_expired?
    @timeout_at ? (Time.now > @timeout_at) : false
  end
  
  def check_for_timeout!
    if (self.ttl_expired?)
      # enter_state(:timeout)
    end
  end

  def log(channel, *args)
    # FIX: Log stuff?
  end

  def valid_hostname?(hostname)
    true
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

    # FIX: This may need to actually close-close on a TCP socket
  end
end
