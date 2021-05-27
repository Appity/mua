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
      result_code, message, continuation = Mua::SMTP::Client::Support.unpack_reply(line)

      if (continuation)
        context.buffer << message
        context.parser_redo!
      else
        buffer, context.buffer = context.buffer, [ ]
        buffer << message

        context.result_code = "SMTP_#{result_code}"
        context.result_message = buffer

        [ result_code, buffer ]
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

    interpret(535) do |context, result_messages|
      # FIX: Not compatible with new model
      handle_reply_continuation(535, message) do |result_code, message|
        @error = message

        context.debug_notification(:error, "[#{@state}] #{result_code} #{message}")
        context.error_notification(result_code, message)

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
      context.ready = true

      if (context.batch.queue_any?)
        context.transition!(state: :deliver)
      elsif (context.batch.closed? or context.close_requested?)
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
      if (context.batch_poll!)
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

    interpret(503) do |context, result_messages|
      # NOTE: Some servers require re-negotiating a EHLO after STARTTLS
      if (result_messages[0].match(/5\.5\.1/))
        context.transition!(state: :re_helo)
      end
    end

    # FIX: Handle sender specific issues (400..599)
    interpret(400..599) do |context, result_code, result_messages|
      unless (context.message.test?)
        context.message.rejected!(
          result_code: "SMTP_#{result_code}",
          result_message: result_messages.join(' ')
        )
      end

      context.transition!(state: :reset)
    end
  end

  state(:rcpt_to) do
    enter do |context|
      if (context.message)
        recipient = context.message.each_rcpt.next

        context.reply("RCPT TO:<#{recipient}>")
      else
        context.message_callback(false, "Delegate has no active message")
        context.transition!(state: :reset)
      end

    rescue StopIteration
      context.message_callback(false, "Message has no recipients")

      message.failed!(
        result_code: 'MAIL_NO_RECIPIENTS',
        result_message: 'Message has no recipients'
      )

      context.transition!(state: :reset)
    end

    interpret(250) do |context, result_messages|
      # FIX: Should test more than one recipient
      if (context.message.test?)
        message.status = :test_passed
        context.transition!(state: :reset)
      else
        recipient = context.message.each_rcpt.next

        context.reply("RCPT TO:<#{recipient}>")
      end

    rescue StopIteration
      context.transition!(state: :data)
    end

    # NOTE: Same handler for soft_bounce and hard_bounce for now
    interpret(400..599) do |context, result_code, result_messages|
      unless (context.message.test?)
        context.message.rejected!(
          result_code: "SMTP_#{result_code}",
          result_message: result_messages.join(' ')
        )
      end

      context.transition!(state: :reset)
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

    interpret(250) do |context, result_messages|
      context.message.delivered!(
        result_code: 'SMTP_250',
        result_message: result_messages.join(' ')
      )

      context.transition!(state: :sent)
    end

    default do |context, result_code, result_messages|
      context.message.rejected!(
        result_code: "SMTP_#{result_code}",
        result_message: result_messages.join(' ')
      )

      context.transition!(state: :reset)
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
      context.ready = false

      context.message&.requeue!

      context.parent_transition!(state: :smtp_finished)
    end
  end

  state(:reset) do
    enter do |context|
      context.message = nil

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

  default do |context, result_code, result_messages|
    # FIX: Determine if it should RSET or QUIT
    # context.transition!(state: @state == :initialized ? :terminated : :reset)

    # context.reply('QUIT')
    # context.terminated!

    context.message&.failed!(
      result_code: "SMTP_#{result_code}",
      result_message: result_messages.join(' ')
    )

    context.transition!(state: :quit)
  end
end
