require_relative '../../constants'
require_relative '../../token'

require_relative 'context'

Mua::SOCKS5::Server::Interpreter = Mua::Interpreter.define(
  name: 'Mua::SOCKS5::Server::Interpreter',
  context: Mua::SOCKS5::Server::Context
) do
  state(:initialize) do
    parser(exactly: 2, unpack: 'CC')

    default do |context, version, nmethods|
      case (version)
      when Mua::Constants::SOCKS5_VERSION
        if (nmethods > 0)
          context.auth_methods = context.read_exactly(nmethods, unpack: 'C*')
        end
  
        context.transition!(state: :reply)
      else
        Mua::SOCKS5::Server::IncompatibleVersion
      end
    end
  end
  
  state(:reply) do
    enter do |context|
      # FIX: Check auth required vs. authentication methods listed
      if (context.auth_required?)
        context.packreply(
          'CC',
          Mua::Constants::SOCKS5_VERSION,
          Mua::Constants::SOCKS5_METHOD[:username_password]
        )

        context.transition!(state: :auth_username_password)
      else
        context.packreply(
          'CC',
          Mua::Constants::SOCKS5_VERSION,
          Mua::Constants::SOCKS5_METHOD[:no_auth]
        )

        context.transition!(state: :request)
      end
    end
  end
  
  state(:request) do
    parser(exactly: 4, unpack: 'CCxC') do |context, version, command, addr_type|
      case (version)
      when Mua::Constants::SOCKS5_VERSION
        [ command, addr_type ]
      else
        Mua::SOCKS5::Server::IncompatibleVersion
      end
    end

    interpret(0x01) do |context, addr_type|
      case (addr_type)
      when 0x01
        context.target_addr_type = :ipv4

        target_addr, target_port = context.read_exactly(6, unpack: 'A4n')

        context.target_addr = IPAddr.ntop(target_addr)
        context.target_port = target_port

        context.transition!(state: :connect)
      when 0x03
        context.target_addr_type = :fqdn

        target_len = context.read_exactly(1, unpack: 'C')
        target_addr, target_port = context.read_exactly(6, unpack: 'A%dn' % target_len)

        context.target_addr = target_addr
        context.target_port = target_port

        context.transition!(state: :connect)
      when 0x04
        context.target_addr_type = :ipv6

        target_addr, target_port = context.read_exactly(18, unpack: 'A16n')

        context.target_addr = IPAddr.ntop(target_addr)
        context.target_port = target_port

        context.transition!(state: :connect)
      else
        Mua::SOCKS5::Server::InvalidAddressType
      end
    end

    default do |context|
      context.write_proxy_reply(0x07) # Command Not Supported

      context.close!
      context.transition!(state: :finished)
    end
  end

  state(:auth_username_password) do
    # FIX: Implement auth
  end

  state(:connect) do
    enter do |context|
      context.target_connect! do |stream, task|
        context.write_proxy_reply(0)

        [
          task.async do
            loop do
              stream.io.wait_readable
              context.input.io.write(stream.io.read_nonblock(512) || break)
            end
          end,
          task.async do
            loop do
              context.input.io.wait_readable
              stream.io.write(context.input.io.read_nonblock(512) || break)
            end
          end
        ].each(&:wait)
      end
      
      context.reactor.print_hierarchy
    end
  end

  interpret(Mua::Token::Timeout) do |context|
    context.transition!(state: :timeout)
  end

  state(:timeout) do
    enter do |context|
      context.close!
      context.transition!(state: :finished)
    end
  end
end