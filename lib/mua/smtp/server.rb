require 'async/io/host_endpoint'

class Mua::SMTP::Server
  # == Constants ============================================================
  
  PORT_DEFAULT = 1025
  BIND_DEFAULT = '127.0.0.1'.freeze
  BACKLOG_DEFAULT = 128
  TIMEOUT_DEFAULT = 30
  
  # == Extensions ===========================================================
  
  # == Properties ===========================================================

  attr_reader :bind
  attr_reader :port
 
  # == Class Methods ========================================================
  
  # == Instance Methods =====================================================

  def initialize(bind: nil, port: nil, start: true, timeout: nil)
    @bind = bind || BIND_DEFAULT
    @port = port || PORT_DEFAULT
    @timeout = timeout || TIMEOUT_DEFAULT

    start! if (start)
  end

  def start!
    @endpoint = Async::IO::Endpoint.tcp(@bind, @port)

    @endpoint.bind do |server, task|
      server.listen(BACKLOG_DEFAULT)

      server.accept_each do |peer|
        peer.timeout = @timeout

        Mua::SMTP::Server::Interpreter.new(
          Async::IO::Stream.new(peer)
        ).run!
      end
    end
  end
end

require_relative 'server/interpreter'
require_relative 'server/context'
