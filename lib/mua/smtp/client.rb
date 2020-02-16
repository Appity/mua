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

    if (@context.proxy?)
      @context.remote_ip = @context.proxy_host
      @context.remote_port = @context.proxy_port
    else
      @context.remote_ip = @context.smtp_host
      @context.remote_port = @context.smtp_port
    end

    @endpoint = Async::IO::Endpoint.tcp(@context.remote_ip, @context.remote_port)

    @signal = Async::Condition.new

    @task = Async do |task|
      begin
        @endpoint.connect do |peer|
          peer.timeout = @context.timeout

          @context.input = Async::IO::Stream.new(peer)
          @context.assign_local_ip!
          @context.assign_remote_ip!

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

  def state
    @interpreter.context.state
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
