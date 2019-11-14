require_relative '../attr_boolean'

class Mua::State::Context
  # == Constants ============================================================
  
  # == Extensions ===========================================================

  extend Mua::AttrBoolean

  # == Properties ===========================================================

  attr_accessor :task
  attr_accessor :state
  
  # == Class Methods ========================================================
  
  # == Instance Methods =====================================================

  def initialize(task: nil, state: nil)
    @task = task
    @state = state
  end
end
