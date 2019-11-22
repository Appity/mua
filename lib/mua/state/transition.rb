class Mua::State::Transition
  # == Constants ============================================================
  
  # == Extensions ===========================================================
  
  # == Properties ===========================================================

  attr_reader :state
  attr_reader :parent
 
  # == Class Methods ========================================================
  
  # == Instance Methods =====================================================

  def initialize(state:, parent: nil)
    @state = state
    @parent = parent
  end
end
