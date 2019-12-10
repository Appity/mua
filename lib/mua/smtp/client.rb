require 'async/io'

require_relative '../client/context'

class Mua::SMTP::Client
  # == Constants ============================================================

  DEFAULTS = {
    smtp_host: nil,
    smtp_port: 25,
    socks5_host: nil,
    socks5_port: 1080,
    timeout: 30
  }.freeze
  
  # == Extensions ===========================================================
  
  # == Properties ===========================================================

  # == Class Methods ========================================================
  
  # == Instance Methods =====================================================
  
  def initialize(**options, &block)
    @reactor = options[:reactor]
    @context = Mua::Client::Context.new(DEFAULTS.merge(options))
    @endpoint =
      if (@context.proxy?)
        Async::IO::Endpoint.tcp(@context.proxy_host, @context.proxy_port)
      else
        Async::IO::Endpoint.tcp(@context.smtp_host, @context.smtp_port)
      end

    @task = @reactor.async do |task|
      @endpoint.connect do |peer|
        @context.input = Async::IO::Stream.new(peer)

        @interpreter = Mua::SMTP::Client::ProxyAwareInterpreter.new(@context)

        @interpreter.run!(&block)
      end
    end
  end

  def deliver!(**args)
    @context.deliver!(Mua::SMTP::Message.new(args))
  end

  def quit!
    @context.quit!
  end
end

require_relative '../client'

require_relative 'client/interpreter'
require_relative 'client/proxy_aware_interpreter'
require_relative 'client/support'
