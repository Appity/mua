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

  def connected?
    !self.closed? and !!self.input
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

    if (self.connected?)
      self.delivery_queue << delivery

      if (self.state == :ready)
        # Force re-entry to begin sending queued messages
        self.interrupt_read!(state: :ready)
      end
    else
      delivery.resolve(
        Mua::Client::DeliveryResult.new(
          message: message,
          result_code: 'CONN_FAIL',
          result_message: 'Connection failed.',
          proxy_host: self.proxy_host,
          proxy_port: self.proxy_port,
          target_host: self.smtp_host,
          target_port: self.smtp_port,
          delivered: false
        )
      )
    end

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

  def delivery_queued_fail!(**args)
    [ self.delivery ].concat(self.delivery_queue).compact.each do |delivery|
      delivery.resolve(
        Mua::Client::DeliveryResult.new(**{
          message: delivery.message,
          proxy_host: self.proxy_host,
          proxy_port: self.proxy_port,
          target_host: self.smtp_host,
          target_port: self.smtp_port,
          delivered: false
        }.merge(args))
      )
    end

    self.delivery = nil
    self.delivery_queue.clear
  end

  def delivery_queued?
    self.delivery_queue.any?
  end

  def quit!
    self.close_requested!

    if (self.state == :ready)
      self.interrupt_read!(state: :quit)
    end
  end

  def interrupt_read!(state: nil)
    @state_target = state
    self.read_task&.stop
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

  def starttls!
    @tls_context = OpenSSL::SSL::SSLContext.new
    self.input.flush
    io = self.input.io

    tls_socket = Async::IO::SSLSocket.new(io, @tls_context)

    self.input = Async::IO::Stream.new(tls_socket)
    yield(self.input) if (block_given?)
    self.input.flush

    true
  end

  def tls_engaged?
    self.input.io.is_a?(Async::IO::SSLSocket)
  end
end
