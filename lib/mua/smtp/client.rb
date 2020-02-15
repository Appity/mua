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
    @context = Mua::Client::Context.new(DEFAULTS.merge(options))
    @endpoint =
      if (@context.proxy?)
        Async::IO::Endpoint.tcp(@context.proxy_host, @context.proxy_port)
      else
        Async::IO::Endpoint.tcp(@context.smtp_host, @context.smtp_port)
      end

    @signal = Async::Condition.new

    @task = Async do |task|
      begin
        @endpoint.connect do |peer|
          peer.timeout = @context.timeout

          @context.input = Async::IO::Stream.new(peer)

          @interpreter = Mua::SMTP::Client::ProxyAwareInterpreter.new(@context)

          @signal.signal

          @interpreter.run(&block)
        end

      rescue Exception => e
        @context.exception = e

        @interpreter = Mua::SMTP::Client::ProxyAwareInterpreter.new(@context)

        @signal.signal

        @interpreter.run(&block)
      end
    end

    @signal.wait
  end

  def deliver!(**args)
    @context.deliver!(Mua::SMTP::Message.new(args))
  end

  def wait
    @task.wait
  end

  def quit!
    @context.quit!
  end
end

require_relative '../client'

require_relative 'client/interpreter'
require_relative 'client/proxy_aware_interpreter'
require_relative 'client/support'
