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

  def batch_poll!
    self.message = self.batch.next
  end

  # def delivery_resolve!(**args)
  #   return unless (self.delivery)

  #   self.delivery.resolve(
  #     Mua::Message::DeliveryResult.new(**{
  #       message: self.message,
  #       proxy_host: self.proxy_host,
  #       proxy_port: self.proxy_port,
  #       target_host: self.smtp_host,
  #       target_port: self.smtp_port,
  #       delivered: false
  #     }.merge(args))
  #   )
  # end

  # def delivery_queued_fail!(**args)
  #   [ self.delivery ].concat(self.delivery_queue).compact.each do |delivery|
  #     delivery.resolve(
  #       Mua::Message::DeliveryResult.new(**{
  #         message: delivery.message,
  #         proxy_host: self.proxy_host,
  #         proxy_port: self.proxy_port,
  #         target_host: self.smtp_host,
  #         target_port: self.smtp_port,
  #         delivered: false
  #       }.merge(args))
  #     )
  #   end
  #
  #   self.delivery = nil
  #   self.delivery_queue.clear
  # end

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

  def message_callback(success, message)
    # ...
  end

  def handle_reply_continuation(result_code, result_message, continues)
    @result_message ||= ''

    if (preamble = @result_message.split(/\s/).first)
      result_message.sub!(/^#{preamble}/, '')
    end

    @result_message << result_message.gsub(/\s+/, ' ')

    unless (continues)
      yield(result_code, @result_message)

      @result_message = nil
    end
  end

  def starttls!
    self.input.flush

    @tls_context = OpenSSL::SSL::SSLContext.new

    self.input = Async::IO::Stream.new(
      Async::IO::SSLSocket.connect(self.input.io, @tls_context)
    )

    yield(self.input) if (block_given?)

    true
  end

  def tls_engaged?
    self.input.io.is_a?(Async::IO::SSLSocket)
  end
end
