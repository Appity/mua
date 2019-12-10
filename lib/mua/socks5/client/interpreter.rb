require_relative '../../constants'

require_relative '../../client/context'

# RFC1928: https://tools.ietf.org/html/rfc1928

Mua::SOCKS5::Client::Interpreter = Mua::Interpreter.define(
  name: 'Mua::SOCKS5::Client::Interpreter',
  context: Mua::Client::Context,
  initial_state: :proxy_connect
) do
  state(:proxy_connect) do
    enter do |context|
      socks_methods = [
        Mua::Constants::SOCKS5_METHOD[:no_auth]
      ]
      
      if (context.proxy_username)
        socks_methods << Mua::Constants::SOCKS5_METHOD[:username_password]
      end
      
      context.proxy_port ||= Mua::Constants::SERVICE_PORT[:socks5]

      context.debug_notification(:proxy, "Initiating proxy connection through #{context.proxy_host}:#{context.proxy_port}")

      context.packreply(
        'CCC*',
        Mua::Constants::SOCKS5_VERSION,
        socks_methods.length,
        *socks_methods
      )
    end
    
    parser(exactly: 2, unpack: 'CC')
    
    interpret(Mua::Constants::SOCKS5_VERSION) do |context, auth_method|
      case (auth_method)
      when Mua::Constants::SOCKS5_METHOD[:username_password]
        context.transition!(state: :authentication)
      else
        context.transition!(state: :request)
      end
    end

    default do |context, _reply|
      # Some kind of error, so abandon connection.
      context.reply_code = 'SOCKS_ERR_PROTOCOL_VERSION'
      context.parent_transition!(state: :proxy_failed)
    end
  end
  
  state(:request) do
    enter do |context|
      case (context.smtp_host_addr_type)
      when :ipv4
        context.packreply(
          'CCxCA4n',
          Mua::Constants::SOCKS5_VERSION,
          Mua::Constants::SOCKS5_COMMAND[:connect],
          Mua::Constants::SOCKS5_ADDRESS_TYPE[:ipv4],
          IPAddr.new(context.smtp_host).hton,
          context.smtp_port
        )

        context.transition!(state: :reply_ipv4)
      when :fqdn
        context.packreply(
          'CCxCCA*n',
          Mua::Constants::SOCKS5_VERSION,
          Mua::Constants::SOCKS5_COMMAND[:connect],
          Mua::Constants::SOCKS5_ADDRESS_TYPE[:fqdn],
          context.smtp_host.length,
          context.smtp_host,
          context.smtp_port
        )

        context.transition!(state: :reply_fqdn)
      when :ipv6
        context.packreply(
          'CCxCA16n',
          Mua::Constants::SOCKS5_VERSION,
          SOCKS5_COMMAND[:connect],
          SOCKS5_ADDRESS_TYPE[:ipv6],
          IPAddr.new(context.smtp_host).hton,
          context.smtp_port
        )

        context.transition!(state: :reply_ipv6)
      else
        raise "Unknown address type: %s" % context.smtp_host_addr_type.inspect
      end
    end
  end

  state(:reply_ipv4) do
    parser(exactly: 10, unpack: 'CCxCA4n') do |context, _version, reply, addr_type, addr, port|
      [
        reply,
        {
          addr: IPAddr.ntop(addr),
          port: port,
          addr_type: addr_type
        }
      ]
    end
  
    interpret(0) do |context, _meta|
      # 0 = Succeeded
      context.parent_transition!(state: :proxy_connected)
    end
    
    default do |context, reply|
      context.reply_code = "SOCKS_ERR#{reply}"

      context.close!
      context.parent_transition!(state: :proxy_failed)
    end
  end

  state(:reply_fqdn) do
    parser(exactly: 5, unpack: 'CCxCC') do |context, _version, reply, addr_type, addr_len|
      addr = context.read_exactly(addr_len)
      port = context.read_exactly(2, unpack: 'C')

      [
        reply,
        {
          addr: addr,
          port: port,
          addr_type: addr_type
        }
      ]
    end

    interpret(0) do |context, _meta|
      # 0 = Succeeded
      context.parent_transition!(state: :proxy_connected)
    end
    
    default do |context, reply|
      context.reply_code = "SOCKS_ERR#{reply}"

      context.close!
      context.parent_transition!(state: :proxy_failed)
    end
  end

  state(:reply_ipv6) do
    parser(exactly: 22, unpack: 'CCxCA16n') do |context, _version, reply, addr_type, addr, port|
      [
        reply,
        {
          addr: IPAddr.ntop(addr),
          port: port,
          addr_type: addr_type
        }
      ]
    end

    interpret(0) do |context, _meta|
      # 0 = Succeeded
      context.parent_transition!(state: :proxy_connected)
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

      context.packreply(
        'CCA*CA*',
        Mua::Constants::SOCKS5_VERSION,
        username.length,
        username,
        password.length,
        password
      )
    end
    
    parser do |context, s|
      # ...??
    end
    
    interpret(0) do |context|
      context.transition!(state: :request)
    end
  end
end
