module Mua::SMTP::Client::ContextExtensions
  def puts(*lines)
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
end
