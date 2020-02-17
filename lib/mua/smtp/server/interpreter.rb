require_relative 'context'
require_relative '../../constants'
require_relative '../../token'

Mua::SMTP::Server::Interpreter = Mua::Interpreter.define(
  name: 'Mua::SMTP::Server::Interpreter',
  context: Mua::SMTP::Server::Context
) do
  parser(line: true, separator: Mua::Constants::CRLF, chomp: true)

  state(:initialize) do
    enter do |context|
      context.reply(context.banner)

      context.event!(self, :connected)

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
    interpret(/\A\s*EHLO\s+(\S+)\s*\z/) do |context, _, helo_hostname|
      if (context.valid_hostname?(helo_hostname))
        context.log(:debug, "#{context.remote_ip}:#{context.remote_port} to #{context.local_ip}:#{context.local_port} Accepting connection from #{helo_hostname}")
        context.helo_hostname = helo_hostname

        context.reply("250-#{context.hostname} Hello #{context.helo_hostname} [#{context.remote_ip}]")
        context.reply("250-AUTH PLAIN")
        context.reply("250-SIZE 35651584")
        context.reply("250-STARTTLS") if (context.tls_configured? and context.tls_advertise?)
        context.reply("250 OK")
      else
        context.log(:debug, "#{context.remote_ip}:#{context.remote_port} to #{context.local_ip}:#{context.local_port} Rejecting connection from #{helo_hostname} because of invalid FQDN")
        context.reply("504 Need fully qualified hostname")
      end
    end

    interpret(/\A\s*HELO\s+(\S+)\s*\z/) do |context, _, helo_hostname|
      if (context.valid_hostname?(helo_hostname))
        context.log(:debug, "#{context.remote_ip}:#{context.remote_port} to #{context.local_ip}:#{context.local_port} Accepting connection from #{helo_hostname}")
        context.helo_hostname = helo_hostname

        context.reply("250 #{context.hostname} Hello #{context.helo_hostname} [#{context.remote_ip}]")
      else
        context.log(:debug, "#{context.remote_ip}:#{context.remote_port} to #{context.local_ip}:#{context.local_port} Rejecting connection from #{helo_hostname} because of invalid FQDN")
        context.reply("504 Need fully qualified hostname")
      end
    end
    
    interpret(/\A\s*MAIL\s+FROM:\s*<([^>]+)>\s*/) do |context, _, address|
      if (Mua::EmailAddress.valid?(address))
        accept, message = context.will_accept_sender?(address)

        if (accept)
          context.message.mail_from = address
        end

        context.reply(message)
      else
        context.reply("501 Email address is not RFC compliant")
      end
    end

    interpret(/\A\s*RCPT\s+TO:\s*<([^>]+)>\s*/) do |context, _, address|
      if (context.message.mail_from)
        if (Mua::EmailAddress.valid?(address))
          accept, message = context.will_accept_recipient?(address)

          if (accept)
            context.message.rcpt_to << address
          end

          context.reply(message)
        else
          context.reply("501 Email address is not RFC compliant")
        end
      else
        context.reply("503 Sender not specified")
      end
    end
    
    interpret(/\A\s*AUTH\s+PLAIN\s+(.*)\s*\z/) do |context, _, auth|
      # 235 2.7.0 Authentication successful
      context.reply("235 Of course!")
    end

    interpret(/\A\s*AUTH\s+PLAIN\s*\z/) do |context|
      # Multi-line authentication method
      context.transition!(state: :auth_plain)
    end
    
    interpret(/\A\s*STARTTLS\s*\z/) do |context|
      if (context.tls_engaged?)
        context.reply("454 TLS already started")
      elsif (context.tls_configured?)
        context.reply("220 TLS ready to start")
        
        context.starttls! do |tls|
          # FIX: Configure with certificates from context
        end
      else
        context.reply("421 TLS not supported")
      end
    end
    
    interpret(/\A\s*DATA\s*\z/) do |context|
      if (context.message.mail_from and context.message.rcpt_to.any?)
        context.reply("354 Supply message data")
        context.transition!(state: :data)
      else
        context.reply("503 valid RCPT command must precede DATA")
      end
    end

    interpret(/\A\s*NOOP\s*\z/) do |context|
      context.reply("250 OK")
    end

    interpret(/\A\s*RSET\s*\z/) do |context|
      context.reply("250 Reset OK")

      context.transition!(state: :reset)
    end
    
    interpret(/\A\s*QUIT\s*\z/) do |context|
      context.reply("221 #{context.hostname} closing connection")

      context.close!

      context.transition!(state: :finished)
    end
  end
  
  state(:data) do
    interpret(/\A\.\z/) do |context|
      context.message.remote_ip = context.remote_ip
      
      accept, message = context.will_accept_transaction?(context.message)
      
      if (accept)
        accept, message = context.receive_transaction(context.message)

        context.event!(self, :deliver_accept, context.message, message)
        
        context.reply(message)
      else
        context.event!(self, :deliver_reject, context.message, message)

        context.reply(message)
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
    # Receive a single line of authentication

    # TODO: Add authentication hook
  end
  
  state(:reply) do
    enter do |context|
      # Random delay if required
      context.reply(@reply)
    end
    
    default do |context, *args|
      context.reply("554 SMTP Synchronization Error")
      context.transition!(state: :ready)
    end
  end

  interpret(Mua::Token::Timeout) do |context|
    context.transition!(state: :timeout)
  end

  state(:timeout) do
    enter do |context|
      context.reply("420 Idle connection closed")

      context.close!
      context.event!(self, :timeout)

      context.transition!(state: :finished)
    end
  end

  state(:finished) do
    enter do |context|
      context.close!

      context.event!(self, :disconnected)
    end
  end

  default do |context, error|
    context.reply("500 Invalid or incomplete command")
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
