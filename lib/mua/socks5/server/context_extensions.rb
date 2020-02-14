module Mua::SOCKS5::Server::ContextExtensions
  def event!(*args)
    self.event&.call(*args)
  end

  def authorized_user?(username, password)
    true
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

  def write_proxy_reply(code)
    case (self.target_addr_type)
    when :ipv4
      self.packreply(
        'CCxCA4n',
        Mua::Constants::SOCKS5_VERSION,
        code,
        0x01,
        IPAddr.new(self.target_addr).hton,
        self.target_port
      )
    when :fqdn
      self.packreply(
        'CCxCCA*n',
        Mua::Constants::SOCKS5_VERSION,
        code,
        0x03,
        self.target_addr.length,
        self.target_addr,
        self.target_port
      )
    when :ipv6
      self.packreply(
        'CCxCA16n',
        Mua::Constants::SOCKS5_VERSION,
        code,
        0x04,
        IPAddr.new(self.target_addr).hton,
        self.target_port
      )
    end
  end

  def target_connect!
    endpoint = Async::IO::Endpoint.tcp(
      self.target_addr,
      self.target_port
    )

    endpoint.connect do |peer|
      self.target_stream = Async::IO::Stream.new(peer)

      if (block_given?)
        self.async do |task|
          yield(self.target_stream, task)
        end.wait
      end
    end

  rescue SocketError => e
    case (e.to_s)
    when /\Agetaddrinfo/
      raise Mua::SOCKS5::Server::UnknownHost
    else
      raise e
    end
  end
end
