module Mua::SMTP::Client::ContextExtensions
  def write(*lines)
    self.input.puts(*lines, separator: Mua::Constants::CRLF)
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
