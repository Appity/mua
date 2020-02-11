require 'resolv'

module Mua::Client::ContextExtensions
  def smtp_host_addr_type
    case (self.smtp_host)
    when nil
      nil
    when Resolv::IPv4::Regex
      :ipv4
    when Resolv::IPv6::Regex
      :ipv6
    else
      :fqdn
    end
  end

  def auth_required?
    !!(self.smtp_username or self.smtp_password)
  end

  def smtp_addr
    if (smtp_port)
      '%s:%d' % [ smtp_host, smtp_port ]
    else
      smtp_host
    end
  end

  def proxy?
    !!self.proxy_host
  end

  def deliver!(message)
    delivery = Mua::Client::Delivery.new(message)

    self.delivery_queue << delivery

    self.force_transition!(state: :deliver, from: :ready)

    delivery
  end

  def delivery_pop
    # REFACTOR: Replace with Async::Queue?
    self.delivery = self.delivery_queue.shift
    self.message = self.delivery&.message
  end

  def delivery_resolve!(**args)
    return unless (self.delivery)

    self.delivery.resolve(
      Mua::Client::DeliveryResult.new(**{
        message: self.message,
        proxy_host: self.proxy_host,
        proxy_port: self.proxy_port,
        target_host: self.smtp_host,
        target_port: self.smtp_port,
        delivered: false
      }.merge(args))
    )
  end

  def delivery_queued?
    self.delivery_queue.any?
  end

  def quit!
    self.close_requested!
    self.force_transition!(state: :quit, from: :ready)
  end

  def force_transition!(state:, from: nil)
    if (!from or self.state == from)
      @state_target = state
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
