require 'async/io/stream'
require_relative '../attr_boolean'
require_relative '../constants'

class Mua::State::Context
  # == Constants ============================================================
  
  # == Extensions ===========================================================

  extend Mua::AttrBoolean

  # == Properties ===========================================================

  attr_accessor :reactor
  attr_accessor :state
  attr_accessor :input
  attr_boolean :terminated
  
  # == Class Methods ========================================================

  def self.define(*attr_list, **attr_spec, &block)
    Builder.class_with_attributes(attr_list, attr_spec, &block)
  end
  
  # == Instance Methods =====================================================

  def initialize(reactor: nil, state: nil, input: nil)
    @reactor = reactor
    @state = state || self.initial_state
    @input = input
    @terminated = false

    yield(self) if (block_given?)
  end

  def initial_state
    Mua::State::INITIAL_DEFAULT
  end

  def final_state
    Mua::State::FINAL_DEFAULT
  end

  # Reads an element out of the provided input array. Subclasses can redefine
  # this behavior to match the type of input object used.
  def read
    case (input)
    when IO, Async::IO::Stream
      @input.read
    when Array
      @input.shift
    else
      @input
    end
  end

  def parser_redo!
    Mua::Parser::Redo
  end

  # Emits a state transition
  def transition!(state:, parent: nil)
    Mua::State::Transition.new(state: state, parent: parent)
  end

  # Emits a local state transition
  def local_transition!(state:)
    Mua::State::Transition.new(state: state, parent: false)
  end

  # Emits a local state transition
  def parent_transition!(state:)
    Mua::State::Transition.new(state: state, parent: true)
  end

  # Emits a state transition to the default final state
  def finished!
    Mua::State::Transition.new(state: self.final_state)
  end

  # Returns true if a reactor is associated with this context, false otherwise.
  def reactor?
    !!@reactor
  end
end

require_relative 'context/builder'
