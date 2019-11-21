require_relative '../../constants'

Mua::SMTP::Client::Interpreter = Mua::Interpreter.define(
  :username,
  :password,
  :remote,
  initial_state: :greeting,
  protocol: {
    default: :smtp
  },
  auth_support: {
    default: false,
    boolean: true
  },
  auth_required: {
    default: false,
    boolean: true
  },
  tls: {
    default: false,
    boolean: true
  },
  proxy: {
    default: false,
    boolean: true
  },
  timeout: {
    default: Mua::Constants::TIMEOUT_DEFAULT
  }
) do
  label('SMTP')
  
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

      enter_state(:terminated)
    end
  end
  
  state(:helo) do
    enter do
      context.send_line("HELO #{context.hostname}")
    end

    interpret(250) do
      if (context.requires_authentication?)
        enter_state(:auth)
      else
        enter_state(:established)
      end
    end
  end
  
  state(:ehlo) do
    enter do
      context.send_line("EHLO #{context.hostname}")
    end

    interpret(250) do |message, continues|
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
          enter_state(:starttls)
        elsif (context.requires_authentication?)
          enter_state(:auth)
        else
          enter_state(:established)
        end
      end
    end
    
    interpret(500..599) do |result_code|
      # RFC1869 suggests trying HELO if EHLO results in some kind of error,
      # typically 5xx, but the actual code varies wildly depending on server.
      context.protocol = :smtp
      enter_state(:helo)
    end
  end
  
  state(:starttls) do
    enter do
      context.send_line("STARTTLS")
    end
    
    interpret(220) do
      context.start_tls
      @tls = true
      
      case (context.protocol)
      when :esmtp
        enter_state(:ehlo)
      else
        enter_state(:helo)
      end
    end
  end

  state(:auth) do
    enter do
      context.send_line('AUTH PLAIN %s' % [
        self.class.encode_auth(
          context.options[:username],
          context.options[:password]
        )
      ])
    end
    
    interpret(235) do
      enter_state(:established)
    end
    
    interpret(535) do |reply_message, continues|
      handle_reply_continuation(535, reply_message, continues) do |reply_code, reply_message|
        @error = reply_message

        context.debug_notification(:error, "[#{@state}] #{reply_code} #{reply_message}")
        context.error_notification(reply_code, reply_message)

        enter_state(:quit)
      end
    end
  end
  
  state(:established) do
    enter do
      context.connect_notification(true)
      
      enter_state(:ready)
    end
  end
  
  state(:ready) do
    enter do
      context.after_ready
    end
    
    interpret(400..499) do
      # Messages like this might indicate a connection time-out, not an
      # actual error.
    end
  end
  
  state(:send) do
    enter do
      enter_state(:mail_from)
    end
  end
  
  state(:mail_from) do
    enter do
      if (context.active_message)
        context.send_line("MAIL FROM:<#{context.active_message[:from]}>")
      else
        context.message_callback(false, "Delegate has no active message")
        enter_state(:reset)
      end
    end

    interpret(250) do
      enter_state(:rcpt_to)
    end
    
    interpret(503) do |message, continues|
      if (message.match(/5\.5\.1/))
        enter_state(:re_helo)
      end
    end
  end
  
  state(:re_helo) do
    enter do
      context.send_line("HELO #{context.hostname}")
    end
    
    interpret(220) do
      if (context.requires_authentication?)
        enter_state(:auth)
      elsif (context.active_message)
        enter_state(:mail_from)
      else
        enter_state(:established)
      end
    end
    
    interpret(250) do
      if (context.requires_authentication?)
        enter_state(:auth)
      else
        enter_state(:established)
      end
    end
  end
  
  state(:rcpt_to) do
    enter do
      if (context.active_message)
        context.send_line("RCPT TO:<#{context.active_message[:to]}>")
      else
        context.message_callback(false, "Delegate has no active message")
        enter_state(:reset)
      end
    end
    
    interpret(250) do |reply_message, continues|
      handle_reply_continuation(250, reply_message, continues) do |reply_code, reply_message|
        if (context.active_message[:test])
          context_call(:after_message_sent, reply_code, reply_message)

          enter_state(:reset)
        else
          enter_state(:data)
        end
      end
    end
    
    interpret(500..599) do |reply_code, reply_message, continues|
      handle_reply_continuation(reply_code, reply_message, continues) do |reply_code, reply_message|
        context_call(:after_message_sent, reply_code, reply_message)

        enter_state(:reset)
      end
    end
  end
  
  state(:data) do
    enter do
      context.send_line("DATA")
    end
    
    interpret(354) do
      enter_state(:sending)
    end
  end
  
  state(:sending) do
    enter do
      data = context.active_message[:data]

      context.debug_notification(:send, data.inspect)

      context.send_data(self.class.encode_data(data))

      # Ensure that a blank line is sent after the last bit of email content
      # to ensure that the dot is on its own line.
      context.send_line
      context.send_line(".")
    end
    
    default do |reply_code, reply_message, continues|
      handle_reply_continuation(reply_code, reply_message, continues) do |reply_code, reply_message|
        context_call(:after_message_sent, reply_code, reply_message)
      end

      enter_state(:sent)
    end
  end
  
  state(:sent) do
    enter do
      enter_state(:ready)
    end
  end
  
  state(:quit) do
    enter do
      context.send_line("QUIT")
    end
    
    interpret(221) do
      enter_state(:terminated)
    end
    
    interpret(502) do
      # "502 5.5.2 Error: command not recognized"
      enter_state(:terminated)
    end
  end
  
  state(:terminated) do
    enter do
      context.close
    end
  end
  
  state(:reset) do
    enter do
      context.send_line("RSET")
    end
    
    interpret(250) do
      enter_state(:ready)
    end
  end
  
  state(:noop) do
    enter do
      context.send_line("NOOP")
    end
    
    interpret(250) do
      enter_state(:ready)
    end
  end
  
  on_error do |reply_code, reply_message, continues|
    handle_reply_continuation(reply_code, reply_message, continues) do |reply_code, reply_message|
      context.message_callback(reply_code, reply_message)
      context.debug_notification(:error, "[#{@state}] #{reply_code} #{reply_message}")
      context.error_notification(reply_code, reply_message)

      context.active_message = nil

      enter_state(@state == :initialized ? :terminated : :reset)
    end
  end

  # == Instance Methods =====================================================

  def close
    if (@state == :ready)
      enter_state(:quit)
    end
  end
  
  def handle_reply_continuation(reply_code, reply_message, continues)
    # FIX: Convert to while or loop
    @reply_message ||= ''
    
    if (preamble = @reply_message.split(/\s/).first)
      reply_message.sub!(/^#{preamble}/, '')
    end
    
    @reply_message << reply_message.gsub(/\s+/, ' ')
    
    unless (continues)
      yield(reply_code, @reply_message)

      @reply_message = nil
    end
  end

  def will_interpret?(proc, args)
    # Can only interpret blocks if the last part of the message has been
    # received. The continue flag is argument index 1. This will only apply
    # to interpret blocks that do not receive arguments.
  
    (proc.arity == 0) ? !args[1] : true
  end
end
