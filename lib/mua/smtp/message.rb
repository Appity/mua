class Mua::SMTP::Message
  # == Constants ============================================================

  STATES = %i[
    queued
    delivered
    rejected
    bounced
    failed
  ].freeze

  STATE_DEFAULT = :queued
  
  # == Extensions ===========================================================
  
  # == Properties ===========================================================

  attr_reader :id
  attr_reader :mail_from
  attr_reader :rcpt_to
  attr_reader :data

  attr_accessor :state
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
    @rcpt_to = args[:rcpt_to] || args['rcpt_to']
    @data = (args[:data] || args['data'])&.to_s&.gsub(/\r?\n/, "\r\n")
    @test = !!(args[:test] || args['test'])

    @state = (args[:state] || args['state'] || STATE_DEFAULT).to_sym
  end

  def test?
    @test
  end

  STATES.each do |s|
    define_method(:"#{s}?") do
      @state == s
    end
  end

  def reply_code=(v)
    @reply_code = v&.to_i
  end
end
