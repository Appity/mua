require 'async/io'

require_relative '../client/context'

class Mua::SMTP::Client
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

    @endpoint = Async::IO::Endpoint.tcp(@context.remote_ip, @context.remote_port)
    ready = Async::Condition.new

    @task = Async do |task|
      task.annotate "#{self.class}##{self.object_id}"

      task.with_timeout(@context.timeout) do
        begin
          @endpoint.connect do |peer|
            peer.timeout = @context.timeout

            @context.input = Async::IO::Stream.new(peer)
            @context.assign_local_ip!
            @context.assign_remote_ip!

            @interpreter = Mua::SMTP::Client::ProxyAwareInterpreter.new(@context)

            ready.signal(true)

            @interpreter.run(&block)
          end

        rescue Errno::ECONNREFUSED
          task.sleep(@context.backoff)
          retry
        rescue Async::Stop
          # This can happen if interrupted or force stopped
        end
      end

    rescue Async::TimeoutError
      # Connection failed, so just bail
      ready.signal(false)
    end

    ready.wait
  end

  def connected?
    !@context.closed?
  end

  def state
    @interpreter.context.state
  end

  def deliver!(...)
    message = Mua::Message.from(...)

    @context.batch << message

    message
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
