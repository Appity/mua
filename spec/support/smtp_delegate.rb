class SMTPDelegate
  DEFAULTS = {
    hostname: 'localhost.local'.freeze
  }.freeze

  attr_accessor :options
  attr_accessor :protocol
  attr_accessor :active_message
  attr_writer :tls_support
  
  def initialize(options = nil)
    @sent = [ ]
    @options = DEFAULTS.merge(options || { })
    @protocol = :smtp
    @started_tls = false
    @tls_support = nil
    @closed = false
  end
  
  def hostname
    @options[:hostname]
  end
  
  def requires_authentication?
    !!@options[:username]
  end
  
  def use_tls?
    !!@options[:use_tls]
  end
  
  def send_line(line  = '', *args)
    @sent << (args.any? ? (line % args) : line)
  end
  
  def start_tls
    @started_tls = true
  end
  
  def started_tls?
    !!@started_tls
  end
  
  def tls_support?
    !!@tls_support
  end
  
  def close
    @closed = true
  end
  
  def closed?
    !!@closed
  end
  
  def clear!
    @sent = [ ]
  end
  
  def size
    @sent.size
  end
  
  def read
    @sent.shift
  end
  
  def method_missing(*args)
    # Ignore other calls which may be made.
  end
end
