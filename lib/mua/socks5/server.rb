require 'async/io/host_endpoint'

class Mua::SOCKS5::Server
  # == Constants ============================================================
  
  PORT_DEFAULT = 1080
  BIND_DEFAULT = '127.0.0.1'.freeze
  BACKLOG_DEFAULT = 128
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

  attr_reader :bind
  attr_reader :port
 
  # == Class Methods ========================================================
  
  # == Instance Methods =====================================================

  def initialize(interpreter: nil, bind: nil, port: nil, start: true, timeout: nil, &block)
    @interpreter = interpreter || Mua::SOCKS5::Server::Interpreter
    @bind = bind || BIND_DEFAULT
    @port = port || PORT_DEFAULT
    @timeout = timeout || TIMEOUT_DEFAULT

    if (start)
      self.start!(&block)
    end
  end

  def start!(&block)
    @endpoint = Async::IO::Endpoint.tcp(@bind, @port)

    @endpoint.bind do |server, task|
      server.listen(BACKLOG_DEFAULT)

      server.accept_each do |peer|
        peer.timeout = @timeout

        @interpreter.new(
          Async::IO::Stream.new(peer)
        ) do |interpreter|
          interpreter.context.reactor = Async::Task.current
          interpreter.context.assign_remote_ip!
        end.run.each do |*e|
          yield(*e) if (block_given?)
        end
      end
    end
  end
end

require_relative 'server/interpreter'
require_relative 'server/context'
