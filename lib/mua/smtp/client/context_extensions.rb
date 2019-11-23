module Mua::SMTP::Client::ContextExtensions
  def reply(*lines)
    self.input.puts(*lines, separator: Mua::Constants::CRLF)
  end

  def deliver!(message)
    self.delivery_queue << message

    self.transition!(state: :ready, from: :ready)
  end

  def quit
    self.transition!(state: :quit, from: :ready)
  end

  def transition!(state:, from: nil)
    if (!from or self.state == from)
      self.state = state
      self.read_task&.stop
    end
  end

  # REFACTOR: Are these useful? The new event model may nullify this
  def connect_notification(code, message = nil)
    # ...
  end

  def debug_notification(code, message)
    # ...
  end

  def error_notification(code, message)
    # ...
  end

  # REFACTOR: Is this useful?
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
end
