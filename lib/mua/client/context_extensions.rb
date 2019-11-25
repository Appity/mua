module Mua::Client::ContextExtensions
  def auth_required?
    !!(self.smtp_username or self.smtp_password)
  end

  def proxy?
    !!self.proxy_host
  end

  def deliver!(message)
    self.message_queue << message

    self.force_transition!(state: :ready, from: :ready)
  end

  def message_pop
    self.message = self.message_queue.shift
  end

  def message_queued?
    self.message_queue.any?
  end

  def quit
    self.close_requested!
    self.force_transition!(state: :quit, from: :ready)
  end

  def force_transition!(state:, from: nil)
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
