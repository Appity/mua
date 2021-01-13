require_relative '../../constants'
require_relative '../../interpreter'
require_relative 'support'

Mua::SMTP::Client::Interpreter = Mua::Interpreter.define(
  name: 'Mua::SMTP::Client::Interpreter',
  context: Mua::Client::Context,
  initial_state: :smtp_connect
) do
  parser do |context|
    context.read_line do |line|
      reply_code, reply_message, continuation = Mua::SMTP::Client::Support.unpack_reply(line)

      if (continuation)
        context.reply_buffer << reply_message
        context.parser_redo!
      else
        buffer, context.reply_buffer = context.reply_buffer, [ ]
        buffer << reply_message

        context.reply_code = "SMTP_#{reply_code}"
        context.reply_message = buffer

        [ reply_code, buffer ]
      end
    end
  end

  state(:initialize) do
    enter do |context|
      context.transition!(state: :smtp_connect)
    end
  end

  state(:smtp_connect) do
    enter do |context|
      context.transition!(state: :banner)
    end
  end

  state(:banner) do
    interpret(220) do |context, messages|
      context.smtp_banner = messages
      message_parts = messages[0].split(/\s+/)
      context.remote_host = message_parts.first

      context.transition!(state: context.protocol == :esmtp ? :ehlo : :helo)
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
      context.reply("HELO #{context.hostname}")
    end

    interpret(250) do |context|
      if (context.auth_required?)
        context.transition!(state: :auth)
      else
        context.transition!(state: :established)
      end
    end
  end

  state(:ehlo) do
    enter do |context|
      context.reply("EHLO #{context.hostname}")
    end

    interpret(250) do |context, messages|
      messages.each_with_index do |message, i|
        next if (i == 0) # First line is not an extension as per RFC1869 (4.3)

        extension, *value = message.split(/\s+/)

        value.map! do |v|
          case (v)
          when /\A\d+\z/
            v.to_i
          else
            v
          end
        end

        case (value.length)
        when 1
          value = value[0]
        when 0
          value = true
        end

        context.service_extensions[extension.downcase.to_sym] = value
      end

      if (context.service_extensions[:starttls] and context.tls_requested? and !context.tls_engaged?)
        context.transition!(state: :starttls)
      elsif (context.auth_required?)
        context.transition!(state: :auth)
      else
        context.transition!(state: :established)
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
      context.reply('STARTTLS')
    end

    interpret(220) do |context|
      context.starttls!

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
      context.reply('AUTH PLAIN %s' % [
        self.class.encode_auth(
          context.options[:username],
          context.options[:password]
        )
      ])
    end

    interpret(235) do |context|
      context.transition!(state: :established)
    end

    interpret(535) do |context, reply_messages|
      # FIX: Not compatible with new model
      handle_reply_continuation(535, reply_message) do |reply_code, reply_message|
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
      if (context.delivery_queued?)
        context.transition!(state: :deliver)
      elsif (context.close_requested?)
        context.transition!(state: :quit)
      end
    end

    interpret(400..499) do |context|
      # Messages like this might indicate a connection time-out, not an
      # actual error.

      # FIX: Handle somehow, reject in-flight deliveries?
    end
  end

  state(:deliver) do
    enter do |context|
      if (context.delivery_pop)
        context.transition!(state: :mail_from)
      end
    end
  end

  state(:mail_from) do
    enter do |context|
      if (context.message)
        context.reply("MAIL FROM:<#{context.message.mail_from}>")
      else
        context.message_callback(false, "Delegate has no active message")
        context.transition!(state: :reset)
      end
    end

    interpret(250) do |context|
      context.transition!(state: :rcpt_to)
    end

    interpret(503) do |context, reply_messages|
      if (reply_messages[0].match(/5\.5\.1/))
        context.transition!(state: :re_helo)
      end
    end
  end

  state(:rcpt_to) do
    enter do |context|
      if (context.message)
        recipient = context.message.rcpt_to_iterator.next

        context.reply("RCPT TO:<#{recipient}>")
      else
        context.message_callback(false, "Delegate has no active message")
        context.transition!(state: :reset)
      end

    rescue StopIteration
      context.message_callback(false, "Message has no recipients")

      context.delivery_resolve!(
        result_code: 'MAIL_NO_RECIPIENTS',
        result_message: 'Message has no recipients',
        delivered: false
      )

      context.transition!(state: :reset)
    end

    interpret(250) do |context, reply_messages|
      # FIX: Should test more than one recipient
      if (context.message.test?)
        message.status = :test_passed
        context.transition!(state: :reset)
      else
        recipient = context.message.rcpt_to_iterator.next

        context.reply("RCPT TO:<#{recipient}>")
      end

    rescue StopIteration
      context.transition!(state: :data)
    end

    # Note! split soft_bounce and hard_bounce for now
    interpret(400..499) do |context, reply_code, reply_messages|
      if (context.message.test?)
        message.status = :test_failed

        context.delivery_resolve!(
          result_code: reply_code,
          result_message: reply_messages.join(' '),
          delivered: false
        )
      else
        context.transition!(state: :reset)
      end
    end

    interpret(500..599) do |context, reply_code, reply_messages|
      if (context.message.test?)
        message.status = :test_failed

        context.delivery_resolve!(
          result_code: reply_code,
          result_message: reply_messages.join(' '),
          delivered: false
        )
      else
        context.transition!(state: :reset)
      end
    end
  end

  state(:data) do
    enter do |context|
      context.reply('DATA')
    end

    interpret(354) do |context|
      context.transition!(state: :sending)
    end
  end

  state(:sending) do
    enter do |context|
      data = context.message.data

      context.debug_notification(:send, data.inspect)

      # FIX: send_data, encode_data
      context.reply(Mua::SMTP::Client::Support.encode_data(data))

      # Ensure that a blank line is sent after the last bit of email content
      # to ensure that the dot is on its own line.
      context.reply
      context.reply(".")
    end

    default do |context, reply_code, reply_messages|
      context.message.reply_code = "SMTP_#{reply_code}"
      context.message.reply_message = reply_messages.join(' ')

      # FIX: This needs to be a lot smarter and interpret responses better
      context.message.state =
        case (reply_code)
        when 250
          :delivered
        else
          :failed
        end

      context.delivery_resolve!(
        result_code: "SMTP_#{reply_code}",
        result_message: reply_messages.join(' '),
        delivered: context.message.state == :delivered
      )

      context.transition!(state: :sent)
    end
  end

  state(:sent) do
    enter do |context|
      context.message = nil
      context.transition!(state: :ready)
    end
  end

  state(:re_helo) do
    enter do |context|
      context.reply("HELO #{context.hostname}")
    end

    interpret(220) do |context|
      if (context.requires_authentication?)
        context.transition!(state: :auth)
      elsif (context.message)
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

  state(:quit) do
    enter do |context|
      context.reply('QUIT')
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
      context.delivery_queued_fail!(
        result_code: 'SMTP_TERM',
        result_message: 'Connection was terminated'
      )

      context.parent_transition!(state: :smtp_finished)
    end
  end

  state(:reset) do
    enter do |context|
      context.reply('RSET')
    end

    interpret(250) do |context|
      context.transition!(state: :ready)
    end
  end

  state(:noop) do
    enter do |context|
      context.reply('NOOP')
    end

    interpret(250) do |context|
      context.transition!(state: :ready)
    end
  end

  default do |context, reply_code, reply_messages|
    # FIX: Determine if it should RSET or QUIT
    # context.transition!(state: @state == :initialized ? :terminated : :reset)

    # context.reply('QUIT')
    # context.terminated!

    if (message = context.message)
      message.reply_code = "SMTP_#{reply_code}"
      message.reply_message = reply_messages.join(' ')
      message.failed!
    end

    context.transition!(state: :quit)
  end
end
