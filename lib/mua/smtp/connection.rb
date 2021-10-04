require_relative '../client/context'

class Mua::SMTP::Connection
  # == Constants ============================================================

  # == Extensions ===========================================================

  # == Properties ===========================================================

  attr_reader :context

  # == Class Methods ========================================================

  # == Instance Methods =====================================================

  def initialize(**options, &block)
    @context = Mua::Client::Context.new(**options)

    if (@context.proxy?)
      @context.remote_ip = @context.proxy_host
      @context.remote_port = @context.proxy_port
    else
      @context.remote_ip = @context.smtp_host
      @context.remote_port = @context.smtp_port
    end

    if (options[:logger])
      @context.smtp_loggers << options[:logger]
    end

    @endpoint = Async::IO::Endpoint.tcp(@context.remote_ip, @context.remote_port)
  end

  def mail_from(addr)
    case (addr)
    when /\A<.*>\z/
      context.reply("MAIL FROM:#{addr}")
    else
      context.reply("MAIL FROM:<#{addr}>")
    end

    self.response
  end

  def rcpt_to(addr)
    case (addr)
    when /\A<.*>\z/
      context.reply("RCPT TO:#{addr}")
    else
      context.reply("RCPT TO:<#{addr}>")
    end

    self.response
  end

  def method_missing(name, *args)
    context.reply("#{name.to_s.upcase.tr('_', ' ')} #{args.join(' ')}")

    self.response
  end

  def connect
    ready = Async::Condition.new

    # @endpoint.connect do |peer|
    #   peer.timeout = @context.timeout

    #   @context.input = Async::IO::Stream.new(peer)
    #   @context.assign_local_ip!
    #   @context.assign_remote_ip!

    #   ready.signal(true)
    # end

    peer = @endpoint.connect
    peer.timeout = @context.timeout

    @context.input = Async::IO::Stream.new(peer)

    if (@context.proxy_host)
      interpreter = Mua::SOCKS5::Client::Interpreter.new(@context)

      interpreter.run
    end

    @context.assign_local_ip!
    @context.assign_remote_ip!

    # ready.signal(true)

    # ready.wait

    self.response
  end

  def response
    response = nil

    loop do
      context.read_line do |line|
        result_code, message, continuation = Mua::SMTP::Client::Support.unpack_reply(line)

        if (continuation)
          context.buffer << message
        else
          buffer, context.buffer = context.buffer, [ ]
          buffer << message

          context.result_code = "SMTP_#{result_code}"
          context.result_message = buffer

          context.smtp_loggers.each do |logger|
            logger.call(:recv, context.result_code, *context.result_message)
          end

          response = [ context.result_code, buffer ]
        end
      end

      break response.flatten if (response)
    end
  end
end
