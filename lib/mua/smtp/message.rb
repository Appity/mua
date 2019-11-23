class Mua::SMTP::Message
  # == Constants ============================================================
  
  # == Extensions ===========================================================
  
  # == Properties ===========================================================

  attr_reader :mail_from
  attr_reader :rcpt_to
  attr_reader :data
  
  # == Class Methods ========================================================
  
  # == Instance Methods =====================================================
  
  def initialize(args = nil)
    args ||= { }
    
    @mail_from = args[:mail_from] || args['mail_from']
    @rcpt_to = args[:rcpt_to] || args['rcpt_to']
    @data = args[:data] || args['data']
    @test = !!(args[:test] || args['test'])
  end

  def test?
    @test
  end
end
