class Mua::Connection::SMTP < Mua::Connection::Base
  # == Constants ============================================================
  
  OPTIONS_DEFAULT = {
    timeout: 60,
    hostname: Socket.gethostname,
    use_tls: true
  }.freeze
  
  # == Extensions ===========================================================

  # == Properties ===========================================================

  attr_boolean :tls_support
  attr_boolean :auth_support
  attr_boolean :error
  attr_boolean :closed

  # == Class Methods ========================================================

  def self.options_with_defaults(options = nil)
    # Override in subclasses to include additional defaults
    OPTIONS_DEFAULT.merge(options || { })
  end
  
  def self.establish!(host_name, host_port, options)
    EventMachine.connect(host_name, host_port, self, options)

  rescue EventMachine::ConnectionError => e
    self.report_exception(e, options)

    false
  end

  # == Instance Methods =====================================================
  
  def initialize(stream, **options)
    super(stream, **options) do
      @hostname = @options[:hostname]

      @messages = [ ]
      @active_message = nil
    end
  end

  # Returns true if the connection requires TLS support, or false otherwise.
  def use_tls?
    !!@options[:use_tls]
  end
  
  # Returns true if the connection will be using a proxy to connect, false
  # otherwise.
  def using_proxy?
    !!@options[:proxy]
  end
  
  # Returns true if the connection will require authentication to complete,
  # that is a username has been supplied in the options, or false otherwise.
  def requires_authentication?
    @options[:username] and !@options[:username].empty?
  end
  
  def proxy_connection_initiated!
    @connecting_to_proxy = false
  end

  def proxy_connection_initiated?
    !!@connecting_to_proxy
  end
  
  # This implements the EventMachine::Connection#completed method by
  # flagging the connection as estasblished.
  def connection_completed
    self.reset_timeout!
  end

  def close
    return if (self.closed?)

    unless (self.timed_out?)
      send_callback(:on_disconnect)
    end

    debug_notification(:closed, "Connection closed")
    
    super

    self.connected = false
    self.closed = true

    @timeout_at = nil
    @interpreter = nil
  end

  def after_ready
    @established = true
    
    reset_timeout!
  end
  
  # -- Callbacks and Notifications ------------------------------------------

  def interpreter_entered_state(interpreter, state)
    debug_notification(:state, "#{interpreter.label.downcase}=#{state}")
  end

  def send_notification(type, code, message)
    case (callback = @options[type])
    when nil, false
      # No notification in this case
    when Proc
      callback.call(code, message)
    when IO
      callback.puts("%s: %s" % [ code.to_s, message ])
    else
      $stderr.puts("%s: %s" % [ code.to_s, message ])
    end
  end

  # EventMachine: Enables TLS support on the connection.
  def start_tls
    debug_notification(:tls, "Started")

    # super
  end
end
