require 'async/io/host_endpoint'

class Mua::SOCKS5::Client
  # == Constants ============================================================
  
  HOST_DEFAULT = '127.0.0.1'.freeze
  PORT_DEFAULT = 1080
  TIMEOUT_DEFAULT = 30

  EVENTS_PROPAGATED = %i[
    connected
    proxy_connect
    proxy_failure
    disconnected
    timeout
  ]

  BUFFER_SIZE = 1024

  # == Tokens ===============================================================

  IncompatibleVersion = Mua::Token.new('IncompatibleVersion')
  InvalidCommand = Mua::Token.new('InvalidCommand')
  InvalidAddressType = Mua::Token.new('InvalidAddressType')

  # == Exceptions ===========================================================

  class UnknownHost < Mua::Error
  end

  class ConnectionFailed < Mua::Error
  end

  # == Extensions ===========================================================
  
  # == Properties ===========================================================

  attr_reader :port
  attr_reader :io
 
  # == Class Methods ========================================================
  
  # == Instance Methods =====================================================

  def initialize(interpreter: nil, smtp_host:, smtp_port:, proxy_host:, proxy_port:, start: true, timeout: nil, &block)
    @interpreter = interpreter || Mua::SOCKS5::Client::Standalone
    @smtp_host = smtp_host
    @smtp_port = smtp_port.to_i
    @proxy_host = proxy_host || HOST_DEFAULT
    @proxy_port = proxy_port&.to_i || PORT_DEFAULT
    @timeout = timeout&.to_i || TIMEOUT_DEFAULT

    if (start)
      self.start!(&block)
    end
  end

  def start!(&block)
    @endpoint = Async::IO::Endpoint.tcp(@proxy_host, @proxy_port)

    @endpoint.connect do |peer|
      peer.timeout = @timeout
      @io = peer

      @interpreter.new(
        Async::IO::Stream.new(peer)
      ) do |interpreter|
        interpreter.context.smtp_host = @smtp_host
        interpreter.context.smtp_port = @smtp_port
        interpreter.context.reactor = Async::Task.current
      end.run do |*e|
        yield(*e) if (block_given?)
      end.wait
    end
  end
end

require_relative 'server/interpreter'
require_relative 'server/context'

require_relative 'client/interpreter'
require_relative 'client/standalone'
