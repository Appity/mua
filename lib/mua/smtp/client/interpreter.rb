require_relative '../../constants'
require_relative 'context'

Mua::SMTP::Client::Interpreter = Mua::Interpreter.define(
  name: 'Mua::SMTP::Client::Interpreter',
  context: Mua::SMTP::Client::Context
) do
  parser(match: "\n") do |data|
    self.class.unpack_reply(data.chomp)
  end
  
  state(:greeting) do
    interpret(220) do |context, message, continues|
      message_parts = message.split(/\s+/)
      context.remote = message_parts.first
      
      if (message.match(/\bESMTP\b/))
        context.protocol = :esmtp
      end

      unless (continues)
        case (context.protocol)
        when :esmtp
          context.transition!(state: :ehlo)
        else
          context.transition!(state: :helo)
        end
      end
    end
    
    interpret(421) do |context, message|
      context.connect_notification(false, "Connection timed out")
      context.debug_notification(:error, "[#{@state}] 421 #{message}")
      context.error_notification(421, message)
      context.send_callback(:on_error)

      context.transition!(state: :terminated)
    end
  end
  
  state(:helo) do
    enter do |context|
      context.write("HELO #{context.hostname}")
    end

    interpret(250) do |context|
      if (context.requires_authentication?)
        context.transition!(state: :auth)
      else
        context.transition!(state: :established)
      end
    end
  end
  
  state(:ehlo) do
    enter do |context|
      context.write("EHLO #{context.hostname}")
    end

    interpret(250) do |context, message, continues|
      message_parts = message.split(/\s+/)

      case (message_parts[0].to_s.upcase)
      when 'SIZE'
        context.max_size = message_parts[1].to_i
      when 'PIPELINING'
        context.pipelining = true
      when 'STARTTLS'
        context.tls_support = true
      when 'AUTH'
        context.auth_support = message_parts[1, message_parts.length].inject({ }) do |h, v|
          h[v] = true
          h
        end
      end

      unless (continues)
        if (context.use_tls? and context.tls_support? and !@tls)
          context.transition!(state: :starttls)
        elsif (context.requires_authentication?)
          context.transition!(state: :auth)
        else
          context.transition!(state: :established)
        end
      end
    end
    
    interpret(500..599) do |context, result_code|
      # RFC1869 suggests trying HELO if EHLO results in some kind of error,
      # typically 5xx, but the actual code varies wildly depending on server.
      context.protocol = :smtp
      context.transition!(state: :helo)
    end
  end
  
  state(:starttls) do
    enter do |context|
      context.write('STARTTLS')
    end
    
    interpret(220) do |context|
      # FIX: Engage TLS
      # context.start_tls
      @tls = true
      
      case (context.protocol)
      when :esmtp
        context.transition!(state: :ehlo)
      else
        context.transition!(state: :helo)
      end
    end
  end

  state(:auth) do
    enter do |context|
      context.write('AUTH PLAIN %s' % [
        self.class.encode_auth(
          context.options[:username],
          context.options[:password]
        )
      ])
    end
    
    interpret(235) do |context|
      context.transition!(state: :established)
    end
    
    interpret(535) do |context, reply_message, continues|
      handle_reply_continuation(535, reply_message, continues) do |reply_code, reply_message|
        @error = reply_message

        context.debug_notification(:error, "[#{@state}] #{reply_code} #{reply_message}")
        context.error_notification(reply_code, reply_message)

        context.transition!(state: :quit)
      end
    end
  end
  
  state(:established) do
    enter do |context|
      context.connect_notification(true)
      
      context.transition!(state: :ready)
    end
  end
  
  state(:ready) do
    enter do |context|
      # context.after_ready
    end
    
    interpret(400..499) do |context|
      # Messages like this might indicate a connection time-out, not an
      # actual error.
    end
  end
  
  state(:send) do
    enter do |context|
      context.transition!(state: :mail_from)
    end
  end
  
  state(:mail_from) do
    enter do |context|
      if (context.active_message)
        context.write("MAIL FROM:<#{context.active_message[:from]}>")
      else
        context.message_callback(false, "Delegate has no active message")
        context.transition!(state: :reset)
      end
    end

    interpret(250) do |context|
      context.transition!(state: :rcpt_to)
    end
    
    interpret(503) do |context, message, continues|
      if (message.match(/5\.5\.1/))
        context.transition!(state: :re_helo)
      end
    end
  end
  
  state(:re_helo) do
    enter do |context|
      context.write("HELO #{context.hostname}")
    end
    
    interpret(220) do |context|
      if (context.requires_authentication?)
        context.transition!(state: :auth)
      elsif (context.active_message)
        context.transition!(state: :mail_from)
      else
        context.transition!(state: :established)
      end
    end
    
    interpret(250) do |context|
      if (context.requires_authentication?)
        context.transition!(state: :auth)
      else
        context.transition!(state: :established)
      end
    end
  end
  
  state(:rcpt_to) do
    enter do |context|
      if (context.active_message)
        context.write("RCPT TO:<#{context.active_message[:to]}>")
      else
        context.message_callback(false, "Delegate has no active message")
        context.transition!(state: :reset)
      end
    end
    
    interpret(250) do |context, reply_message, continues|
      handle_reply_continuation(250, reply_message, continues) do |reply_code, reply_message|
        if (context.active_message[:test])
          context_call(:after_message_sent, reply_code, reply_message)

          context.transition!(state: :reset)
        else
          context.transition!(state: :data)
        end
      end
    end
    
    interpret(500..599) do |context, reply_code, reply_message, continues|
      handle_reply_continuation(reply_code, reply_message, continues) do |reply_code, reply_message|
        context_call(:after_message_sent, reply_code, reply_message)

        context.transition!(state: :reset)
      end
    end
  end
  
  state(:data) do
    enter do |context|
      context.write("DATA")
    end
    
    interpret(354) do |context|
      context.transition!(state: :sending)
    end
  end
  
  state(:sending) do
    enter do |context|
      data = context.active_message[:data]

      context.debug_notification(:send, data.inspect)

      context.send_data(self.class.encode_data(data))

      # Ensure that a blank line is sent after the last bit of email content
      # to ensure that the dot is on its own line.
      context.write
      context.write(".")
    end
    
    default do |context, reply_code, reply_message, continues|
      handle_reply_continuation(reply_code, reply_message, continues) do |reply_code, reply_message|
        context_call(:after_message_sent, reply_code, reply_message)
      end

      context.transition!(state: :sent)
    end
  end
  
  state(:sent) do
    enter do |context|
      context.transition!(state: :ready)
    end
  end
  
  state(:quit) do
    enter do |context|
      context.write("QUIT")
    end
    
    interpret(221) do |context|
      context.transition!(state: :terminated)
    end
    
    interpret(502) do |context|
      # "502 5.5.2 Error: command not recognized"
      context.transition!(state: :terminated)
    end
  end
  
  state(:terminated) do
    enter do |context|
      # context.close
    end
  end
  
  state(:reset) do
    enter do |context|
      context.write("RSET")
    end
    
    interpret(250) do |context|
      context.transition!(state: :ready)
    end
  end
  
  state(:noop) do
    enter do |context|
      context.write("NOOP")
    end
    
    interpret(250) do |context|
      context.transition!(state: :ready)
    end
  end
  
  # FIX: Add on_error support
  # on_error do |context, reply_code, reply_message, continues|
  #   context.handle_reply_continuation(reply_code, reply_message, continues) do |reply_code, reply_message|
  #     context.message_callback(reply_code, reply_message)
  #     context.debug_notification(:error, "[#{@state}] #{reply_code} #{reply_message}")
  #     context.error_notification(reply_code, reply_message)

  #     context.active_message = nil

  #     context.transition!(state: @state == :initialized ? :terminated : :reset)
  #   end
  # end
end
