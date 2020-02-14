class Mua::State::Transition
  # == Constants ============================================================
  
  # == Extensions ===========================================================
  
  # == Properties ===========================================================

  attr_reader :state
  attr_accessor :parent
 
  # == Class Methods ========================================================
  
  # == Instance Methods =====================================================

  def initialize(state:, parent: nil)
    @state = state
    @parent = parent
  end

  def deparent!
    @parent = nil

    self
  end
end
