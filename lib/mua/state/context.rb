require_relative '../attr_boolean'

class Mua::State::Context
  # == Constants ============================================================
  
  # == Extensions ===========================================================

  extend Mua::AttrBoolean

  # == Properties ===========================================================

  attr_accessor :task
  attr_accessor :state
  attr_boolean :terminated
  
  # == Class Methods ========================================================
  
  # == Instance Methods =====================================================

  def initialize(task: nil, state: nil)
    @task = task
    @state = state
    @terminated = false
  end

  def transition!(target: nil, state:)
    Mua::State::Transition.new(target: target, state: state)
  end
end
