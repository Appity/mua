class Mua::Client::Delivery
  # == Constants ============================================================
  
  # == Extensions ===========================================================
  
  # == Properties ===========================================================

  attr_reader :message
  attr_reader :result

  # == Class Methods ========================================================
  
  # == Instance Methods =====================================================
  
  def initialize(message)
    @message = message
    @signal = Async::Condition.new
  end

  def resolve(result)
    @result = result

    @signal.signal(result)
  end

  def wait
    @result or @signal.wait
  end
end
