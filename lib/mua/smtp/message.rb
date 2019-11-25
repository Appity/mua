class Mua::SMTP::Message
  # == Constants ============================================================

  STATES = %i[
    queued
    delivered
    test_passed
    test_failed
    rejected
    bounced
    failed
  ].freeze

  STATE_DEFAULT = :queued
  
  # == Extensions ===========================================================
  
  # == Properties ===========================================================

  attr_reader :id
  attr_accessor :mail_from
  attr_reader :rcpt_to
  attr_accessor :data

  attr_accessor :state
  attr_accessor :remote_ip
  attr_accessor :auth_username

  attr_reader :reply_code
  attr_accessor :reply_message
  
  # == Class Methods ========================================================

  def self.states
    STATES
  end
  
  # == Instance Methods =====================================================
  
  def initialize(args = nil)
    args ||= { }
    
    @id = args[:id] || args['id']
    @mail_from = args[:mail_from] || args['mail_from']
    @rcpt_to = [ args[:rcpt_to] || args['rcpt_to'] ].flatten.compact
    @data = (args[:data] || args['data']).to_s.gsub(/\r?\n/, "\r\n")
    @test = !!(args[:test] || args['test'])

    @remote_ip = args[:remote_ip] || args['remote_ip']
    @auth_username = args[:auth_username] || args['auth_username']

    @state = (args[:state] || args['state'] || STATE_DEFAULT).to_sym
  end

  def rcpt_to_iterator
    @rcpt_to_iterator ||= @rcpt_to.each
  end

  def test?
    @test
  end

  def complete?
    [ @mail_from, @rcpt_to, @data ].all? do |v|
      v and v.match?(/\S/)
    end
  end

  STATES.each do |s|
    define_method(:"#{s}?") do
      @state == s
    end

    define_method(:"#{s}!") do
      @state = s
    end
  end

  def reply_code=(v)
    @reply_code = v&.to_i
  end
end
