require 'base64'

require_relative 'context'
require_relative '../../constants'
require_relative '../../token'

Mua::SMTP::Server::Interpreter = Mua::Interpreter.define(
  name: 'Mua::SMTP::Server::Interpreter',
  context: Mua::SMTP::Server::Context
) do
  parser(line: true, separator: Mua::Constants::LF, chomp: true)

  state(:initialize) do
    enter do |context|
      context.reply(context.banner)

      context.event!(context, self, :connected)

      context.transition!(state: :reset)
    end
  end

  state(:reset) do
    enter do |context|
      context.reset_transaction!

      context.transition!(state: :ready)
    end
  end

  state(:ready) do
    interpret(/\A\s*EHLO\s+(\S+)\s*\z/i) do |context, _, helo_hostname|
      reject, message = context.will_accept_connection?(helo_hostname, context)

      if (!reject)
        context.reply(message)

        context.log(:debug, "#{context.remote_ip}:#{context.remote_port} to #{context.local_ip}:#{context.local_port} Rejecting cconnection from #{helo_hostname}")

        context.close!
        context.event!(context, self, :connection_refused)

        context.transition!(state: :finished)
      elsif (context.valid_hostname?(helo_hostname))
        context.log(:debug, "#{context.remote_ip}:#{context.remote_port} to #{context.local_ip}:#{context.local_port} Accepting connection from #{helo_hostname}")
        context.helo_hostname = helo_hostname

        context.reply("250-#{context.hostname} Hello #{context.helo_hostname} [#{context.remote_ip}]")
        context.reply('250-AUTH PLAIN')
        context.reply('250-STARTTLS') if (context.tls_configured? and context.tls_advertise?)
        context.reply('250 SIZE 35651584')
      else
        context.log(:debug, "#{context.remote_ip}:#{context.remote_port} to #{context.local_ip}:#{context.local_port} Rejecting connection from #{helo_hostname} because of invalid FQDN")
        context.reply('504 Need fully qualified hostname')
      end
    end

    interpret(/\A\s*HELO\s+(\S+)\s*\z/i) do |context, _, helo_hostname|
      accept, reply = context.will_accept_connection?(helo_hostname, context)

      if (!accept)
        context.reply(reply)

        context.log(:debug, "#{context.remote_ip}:#{context.remote_port} to #{context.local_ip}:#{context.local_port} Rejecting cconnection from #{helo_hostname}")

        context.close!
        context.event!(context, self, :connection_refused)

        context.transition!(state: :finished)
      elsif (context.valid_hostname?(helo_hostname))
        context.log(:debug, "#{context.remote_ip}:#{context.remote_port} to #{context.local_ip}:#{context.local_port} Accepting connection from #{helo_hostname}")
        context.helo_hostname = helo_hostname

        context.reply("250 #{context.hostname} Hello #{context.helo_hostname} [#{context.remote_ip}]")
      else
        context.log(:debug, "#{context.remote_ip}:#{context.remote_port} to #{context.local_ip}:#{context.local_port} Rejecting connection from #{helo_hostname} because of invalid FQDN")
        context.reply('504 Need fully qualified hostname')
      end
    end

    interpret(/\A\s*MAIL\s+FROM:\s*<([^>]+)>\s*/i) do |context, _, address|
      if (Mua::EmailAddress.valid?(address))
        accept, reply = context.will_accept_sender?(address)

        if (accept)
          context.message.mail_from = address
        end

        context.reply(reply)
      else
        context.reply('501 Email address is not RFC compliant')
      end
    end

    interpret(/\A\s*RCPT\s+TO:\s*<([^>]+)>\s*/i) do |context, _, address|
      if (context.message.mail_from)
        if (Mua::EmailAddress.valid?(address))
          accept, reply = context.will_accept_recipient?(address)

          if (accept)
            context.message.rcpt_to << address
          end

          context.reply(reply)
        else
          context.reply('501 Email address is not RFC compliant')
        end
      else
        context.reply('503 Sender not specified')
      end
    end

    interpret(/\A\s*AUTH\s+PLAIN\s+(.*)\s*\z/i) do |context, _, auth|
      username, password = Base64.decode64(auth).split(/\x00/)[1,2]

      context.authenticate!(username, password)
    end

    interpret(/\A\s*AUTH\s+PLAIN\s*\z/i) do |context|
      # Multi-line authentication method
      context.transition!(state: :auth_plain)
    end

    interpret(/\A\s*AUTH\s+LOGIN\s*\z/i) do |context|
      # Multi-line authentication method
      context.transition!(state: :auth_login_username)
    end

    interpret(/\A\s*STARTTLS\s*\z/i) do |context|
      if (context.tls_engaged?)
        context.reply('454 TLS already started')
      elsif (context.tls_configured?)
        context.reply('220 TLS ready to start')

        context.starttls! do |tls|
          # FIX: Configure with certificates from context
        end or context.transition!(state: :finished)
      else
        context.reply('421 TLS not supported')
      end
    end

    interpret(/\A\s*DATA\s*\z/i) do |context|
      if (context.message.mail_from and context.message.rcpt_to.any?)
        context.reply('354 Supply message data')
        context.transition!(state: :data)
      else
        context.reply('503 valid RCPT command must precede DATA')
      end
    end

    interpret(/\A\s*NOOP\s*\z/i) do |context|
      context.reply('250 OK')
    end

    interpret(/\A\s*RSET\s*\z/i) do |context|
      context.reply('250 Reset OK')

      context.transition!(state: :reset)
    end

    interpret(/\A\s*QUIT\s*\z/i) do |context|
      context.reply("221 #{context.hostname} closing connection")

      context.close!

      context.transition!(state: :finished)
    end

    interpret(/\A\s*\z/) do
      # Ignore blank lines.
    end
  end

  state(:data) do
    interpret(/\A\.\z/) do |context|
      context.message.remote_ip = context.remote_ip

      accept, reply = context.will_accept_transaction?(context.message)

      if (accept)
        _accept, reply = context.receive_transaction(context.message)

        context.event!(context, self, :deliver_accept, context.message, reply)

        context.reply(reply)
      else
        context.event!(context, self, :deliver_reject, context.message, reply)

        context.reply(reply)
      end

      context.reset_transaction!

      context.transition!(state: :ready)
    end

    default do |context, line|
      # RFC5321 4.5.2 - Leading dot is removed if line has content
      context.message.data << line.delete_prefix('.') << Mua::Constants::CRLF
    end
  end

  state(:auth_plain) do
    enter do |context|
      # Receive a single line of authentication
      context.reply('334 Proceed')
    end

    default do |context, auth|
      username, password = Base64.decode64(auth).split(/\x00/)[1,2]

      context.authenticate!(username, password)
    end
  end

  state(:auth_login_username) do
    enter do |context|
      context.reply('334 %s' % [ Base64.strict_encode64("User Name\x00") ])
    end

    default do |context, line|
      context.auth_username = Base64.decode64(line)

      context.transition!(state: :auth_login_password)
    end
  end

  state(:auth_login_password) do
    enter do |context|
      context.reply('334 %s' % [ Base64.strict_encode64("Password\x00") ])
    end

    default do |context, line|
      password = Base64.decode64(line)

      context.authenticate!(context.auth_username, password)
    end
  end

  state(:reply) do
    enter do |context|
      # Random delay if required
      context.reply(@reply)
    end

    default do |context, *args|
      context.reply('554 SMTP Synchronization Error')
      context.transition!(state: :ready)
    end
  end

  interpret(Mua::Token::Timeout) do |context|
    context.transition!(state: :timeout)
  end

  state(:timeout) do
    enter do |context|
      context.reply('420 Idle connection closed')

      context.close!
      context.event!(context, self, :timeout)

      context.transition!(state: :finished)
    end
  end

  state(:finished) do
    enter do |context|
      context.close!

      context.event!(context, self, :disconnected)
    end
  end

  default do |context, error|
    context.reply('500 Invalid or incomplete command')
  end

  rescue_from(Errno::EPIPE) do |context|
    # Connection died.
    context.input.close
    context.transition!(state: :finished)
  end

  rescue_from(Errno::ECONNRESET) do |context|
    context.transition!(state: :finished)
  end

  rescue_from(IOError) do |context|
    context.transition!(state: :finished)
  end
end
