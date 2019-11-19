require_relative '../attr_boolean'

class Mua::State::Context
  # == Constants ============================================================
  
  # == Extensions ===========================================================

  extend Mua::AttrBoolean

  # == Properties ===========================================================

  attr_accessor :task
  attr_accessor :state
  attr_accessor :input
  attr_boolean :terminated
  
  # == Class Methods ========================================================

  def self.with_attributes(*attr_list, **attr_spec)
    Builder.class_with_attributes(attr_list, attr_spec)
  end
  
  # == Instance Methods =====================================================

  def initialize(task: nil, state: nil, input: nil)
    @task = task
    @state = state
    @input = input
    @terminated = false

    yield(self) if (block_given?)
  end

  # Reads an element out of the provided input array. Subclasses can redefine
  # this behavior to match the type of input object used.
  def read
    @input&.shift
  end

  # Emits a state transition
  def transition!(target: nil, state:)
    Mua::State::Transition.new(target: target, state: state)
  end

  # Emits a state transition to the `:finished` state
  def finished!
    Mua::State::Transition.new(state: :finished)
  end

  # Returns true if a task is associated with this context, false otherwise.
  def task?
    !!@task
  end
end

require_relative 'context/builder'
