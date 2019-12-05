require_relative '../../constants'

Mua::SOCKS5::Client::Interpreter = Mua::Interpreter.define do
  state(:initialized) do
    enter do |context|
      socks_methods = [ ]
      
      if (context.proxy_username)
        socks_methods << Mua::Constants::SOCKS5_METHOD[:username_password]
      end
      
      context.proxy_port ||= Mua::Constants::SERVICE_PORT[:socks5]

      context.debug_notification(:proxy, "Initiating proxy connection through #{context.proxy_host}:#{context.proxy_port}")

      context.write(
        [
          Mua::Constants::SOCKS5_VERSION,
          socks_methods.length,
          socks_methods
        ].flatten.pack('CCC*')
      )
    end
    
    parser(exactly: 2) do |context, bytes|
      _version, method = bytes.slice!(0,2).unpack('CC')
    
      method
    end
    
    interpret(Mua::Constants::SOCKS5_METHOD[:username_password]) do |context|
      context.transition!(state: :authentication)
    end
    
    default do |context|
      context.transition!(state: :request)
    end
  end
  
  state(:request) do
    enter do |context|
      case (context.smtp_host_address_type)
      when :ipv4
        context.write([
          Mua::Constants::SOCKS5_VERSION,
          Mua::Constants::SOCKS5_COMMAND[:connect],
          Mua::Constants::SOCKS5_ADDRESS_TYPE[:ipv4],
          Socket.sockaddr_in(0, context.smtp_host)[4, 4],
          context.smtp_port
        ].pack('CCxCSn'))

        context.transition!(state: :reply_ipv4)
      when :fqdn
        context.write([
          Mua::Constants::SOCKS5_VERSION,
          Mua::Constants::SOCKS5_COMMAND[:connect],
          Mua::Constants::SOCKS5_ADDRESS_TYPE[:domainname],
          context.smtp_host.length,
          context.smtp_host,
          context.smtp_port
        ].pack('CCxCCA*dn'))

        context.transition!(state: :reply_hostname)
      when :ipv6
        context.write([
          Mua::Constants::SOCKS5_VERSION,
          SOCKS5_COMMAND[:connect],
          SOCKS5_ADDRESS_TYPE[:ipv6],
          Socket.sockaddr_in(0, context.smtp_host)[8, 16],
          context.smtp_port
        ].pack('CCxCA16n'))

        context.transition!(state: :reply_ipv6)
      end
    end
  end

  state(:reply_ipv4) do
    parser(exactly: 10) do |context, s|
      _version, reply, address_type, address, port = s.unpack('CCxCNn')
    
      [
        reply,
        {
          address: address,
          port: port,
          address_type: address_type
        }
      ]
    end
  
    interpret(0) do |context, _meta|
      # 0 = Succeeded
      context.transition!(state: :connected)
    end
    
    default do |context, reply|
      context.reply_code = "SOCKS_ERR#{reply}"

      context.close!
      context.parent_transition!(state: :proxy_failed)
    end
  end

  state(:reply_hostname) do
    # ... parser() needs to take a dynamic argument to implement this
  end

  state(:reply_ipv6) do
    parser(exactly: 22) do |context, s|
      _version, reply, address_type, address, port = s.slice!(0,10).unpack('CCxCA16n')
    
      [
        reply,
        {
          address: address,
          port: port,
          address_type: address_type
        }
      ]
    end

    interpret(0) do |context, _meta|
      # 0 = Succeeded
      context.transition!(state: :connected)
    end
    
    default do |context, reply|
      context.reply_code = "SOCKS_ERR#{reply}"

      context.close!
      context.parent_transition!(state: :proxy_failed)
    end
  end

  state(:authentication) do
    enter do |context|
      proxy_options = context.options[:proxy]
      username = context.proxy_username
      password = context.proxy_password

      write(
        [
          Mua::Constants::SOCKS5_VERSION,
          username.length,
          username,
          password.length,
          password
        ].pack('CCA*CA*')
      )
    end
    
    parser do |context, s|
      # ...??
    end
    
    interpret(0) do |context|
      context.parent_transition!(state: :proxy_connected)
    end
  end
end
