require_relative '../constants'

class Mua::Connection::Base
  # == Exceptions ===========================================================
  
  class CallbackArgumentsRequired < Exception; end

  # == Constants ============================================================
  
  include Mua::Constants

  NOTIFICATIONS = [
    :debug,
    :error,
    :connect
  ].freeze
  
  # == Extensions ===========================================================

  extend Mua::AttrBoolean

  # == Properties ===========================================================
  
  attr_reader :stream
  attr_reader :options
  attr_reader :error
  attr_reader :error_message

  # == Class Methods ========================================================

  def self.options_with_defaults(options = nil)
    # Override in subclasses to include additional defaults
    OPTIONS_DEFAULT.merge(options || { })
  end

  # Warns about supplying a Proc which does not appear to accept the required
  # number of arguments.
  def self.verify_callback_arity(proc, range)
    return if (range.include?(proc.arity) or proc.arity == -1)

    $stderr.puts("Callback must accept %s argument(s) but accepts %d" % [
      [ range.min, range.max ].uniq.join(' to '),
      proc.arity
    ])
  end
  
  # Handles callbacks driven by exceptions before an instance could be created.
  def self.report_exception(e, options)
    case (handler = options[:connect])
    when Proc
      handler.call(false, e.to_s)
    when IO
      handler.puts(e.to_s)
    end
    
    case (handler = options[:on_error])
    when Proc
      handler.call(e.to_s)
    when IO
      handler.puts(e.to_s)
    end

    case (handler = options[:debug])
    when Proc
      handler.call(:error, e.to_s)
    when IO
      handler.puts(e.to_s)
    end
    
    case (handler = options[:error])
    when Proc
      handler.call(:connect_error, e.to_s)
    when IO
      handler.puts(e.to_s)
    end
    
    false
  end
  
  def self.capture_exceptions
    yield

  rescue Object => e
    # To allow for debugging, exceptions are dumped to STDERR as a last resort.
    # Exceptions generated here are eaten and ignored.
    self.report_exception(e, @options) rescue nil

    $stderr.puts("#{e.class}: #{e}") rescue nil
  end

  # == Instance Methods =====================================================
  
  def initialize(stream, **options)
    self.class.capture_exceptions do
      @stream = stream
      @options = options

      yield(self) if (block_given?)
    
      NOTIFICATIONS.each do |type|
        callback = @options[type]

        if (callback.is_a?(Proc))
          self.class.verify_callback_arity(callback, (2..2))
        end
      end
    
      debug_notification(:options, @options.inspect)
    
      self.reset_timeout!

      self.after_initialize
    end
  end

  def initialize_internals
    # Defined in subclasses to add additional behavior to initialize.
  end

  def interpreter
    # Assign initial interpreter in subclass.
  end

  def run!
    # Implement in subclasses to establish runtime behavior.
    # @interpreter = self.interpreter

    # Async.do |task|
    #   loop do
    #     break unless (@interpreter)

    #     @interpreter.run!(@stream)
    #   end
    # end
  end

  # Can be used to define a block to be executed after the connection is
  # complete.
  def after_complete
    if (block_given?)
      @options[:after_complete] = Proc.new
    elsif (@options[:after_complete])
      @options[:after_complete].call
    end
  end

  # Reassigns the timeout which is specified in seconds. Values equal to
  # or less than zero are ignored and a default is used instead.
  def timeout=(value)
    @timeout = value.to_i
    @timeout = TIMEOUT_DEFAULT if (@timeout <= 0)
  end

  # FIX: This won't just magically receive data
  def receive_data(data = nil)
    self.class.capture_exceptions do
      reset_timeout!

      @buffer ||= ''
      @buffer << data if (data)

      if (interpreter = @interpreter)
        interpreter.process(@buffer) do |reply|
          debug_notification(:receive, "[#{interpreter.label}] #{reply.inspect}")
        end
      else
        error_notification(:out_of_band, "Receiving data before a protocol has been established.")
      end
    end
  end

  def post_init
    self.set_timer!
  end
  
  # Returns the current state of the active interpreter, or nil if no state
  # is assigned.
  def state
    @interpreter&.state
  end

  # Sends a single line to the remote host with the appropriate CR+LF
  # delmiter at the end. Can use sprintf-style placeholder values if additional
  # arguments are specified for the values.
  def send_line(line = '', *args)
    reset_timeout!

    @stream.write((args.any? ? (line % args) : line) + CRLF)

    debug_notification(:send, line.inspect)
  end

  # Resolves a hostname to an IP address. Returns the address if resolved,
  # nil otherwise. Accepts an optional block which is called if resolved.
  def resolve_hostname(hostname)
    record = Socket.gethostbyname(hostname)
    
    # FIXME: IPv6 Support here
    address = (record and record[3])
    
    if (address)
      debug_notification(:resolver, "Address #{hostname} resolved as #{address.unpack('CCCC').join('.')}")
    else
      debug_notification(:resolver, "Address #{hostname} could not be resolved")
    end
    
    yield(address) if (block_given?)

    address

  rescue
    # FIX: Narrow down exception list
    nil
  end

  # Resets the timeout time. Returns the time at which a timeout will occur.
  def reset_timeout!
    @timeout_at = Time.now + @timeout
  end
  
  # Returns the number of seconds remaining until a timeout will occur, or
  # nil if no time-out is pending.
  def time_remaning
    @timeout_at and (@timeout_at - Time.now)
  end
  
  def set_timer!
    # FIX: EventMachine
    # UPDATE: task.with_timeout(??)
    @timer = EventMachine.add_periodic_timer(1) do
      self.check_for_timeouts!
    end
  end
  
  def cancel_timer!
    return unless (@timer)

    @timer.cancel
    @timer = nil
  end

  # Checks for a timeout condition, and if one is detected, will close the
  # connection and send appropriate callbacks.
  def check_for_timeouts!
    return if (!@timeout_at or Time.now < @timeout_at or @timed_out)

    @timed_out = true
    @timeout_at = nil

    if (@connected and @active_message)
      message_callback(:timeout, "Response timed out before send could complete")
      error_notification(:timeout, "Response timed out")
      debug_notification(:timeout, "Response timed out")
      send_callback(:on_error)
    elsif (!@connected)
      remote_options = @options
      interpreter = @interpreter
      
      if (self.proxy_connection_initiated?)
        remote_options = @options[:proxy]
      end
      
      message = "Timed out before a connection could be established to #{remote_options[:host]}:#{remote_options[:port]}"
      
      if (interpreter)
        message << " using #{interpreter.label}"
      end
      
      connect_notification(false, message)
      debug_notification(:timeout, message)
      error_notification(:timeout, message)

      send_callback(:on_error)
    else
      interpreter = @interpreter

      if (interpreter and interpreter.respond_to?(:close))
        interpreter.close
      else
        send_callback(:on_disconnect)
      end
    end

    self.close
  end
  
  # Returns true if the connection has been closed, false otherwise.
  def closed?
    @stream.closed?
  end
  
  # Returns true if an error has occurred, false otherwise.
  def error?
    !!@error
  end

  # Closes down the connection.
  def close
    return if (@closed)

    unless (@timed_out)
      send_callback(:on_disconnect)
    end

    debug_notification(:closed, "Connection closed")

    @stream.close

    @connected = false
    @timeout_at = nil
    @interpreter = nil
  end

  # This implements the EventMachine::Connection#unbind method to capture
  # a connection closed event.
  def unbind
    return if (@unbound)

    self.cancel_timer!

    self.after_unbind

    @unbound = true
    @connected = false
    @timeout_at = nil
    @interpreter = nil

    send_callback(:on_disconnect)
  end

  # Returns true if the connection has been unbound by EventMachine, false
  # otherwise.
  def unbound?
    !!@unbound
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
    super
  end
  
  def connected?
    @connected
  end
  
  def connect_notification(code, message = nil, *args)
    @connected = code

    send_notification(:connect, code, (args.any? ? (message % args) : message) || self.remote)
    
    if (code)
      send_callback(:on_connect)
    end
  end

  def error_notification(code, message, *args)
    @error = code
    @error_message = (args.any? ? (message % args) : message)

    send_notification(:error, code, message)
  end

  def debug_notification(code, message, *args)
    send_notification(:debug, code, (args.any? ? (message % args) : message))
  end

  def message_callback(reply_code, reply_message)
    active_message = @active_message
    
    if (callback = (active_message and active_message[:callback]))
      # The callback is screened in advance when assigned to ensure that it
      # has only 1 or 2 arguments. There should be no else here.
      case (callback.arity)
      when 2
        callback.call(reply_code, reply_message)
      when 1
        callback.call(reply_code)
      end
    end
  end
  
  def send_callback(type)
    if (callback = @options[type])
      case (callback.arity)
      when 1
        callback.call(self)
      else
        callback.call
      end
    end
  end
end
