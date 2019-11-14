class Mua::State::Transition
  # == Constants ============================================================
  
  # == Extensions ===========================================================
  
  # == Properties ===========================================================

  attr_reader :target
  attr_reader :state
 
  # == Class Methods ========================================================
  
  # == Instance Methods =====================================================

  def initialize(target: nil, state: )
    @target = target
    @state = state
  end
end
