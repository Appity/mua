require_relative 'state'

class Mua::Interpreter
  # == Constants ============================================================
  
  # == Extensions ===========================================================
  
  # == Properties ===========================================================
  
  attr_reader :context
  attr_reader :machine

  # == Class Methods ========================================================

  def self.define(*attr_list, name: nil, **attr_spec, &block)
    Class.new(Mua::Interpreter) do
      context = Mua::State::Context.define(*attr_list, **attr_spec)
      machine = Mua::State::Machine.define(
        name: name,
        **attr_spec.slice(:initial_state, :final_state),
        &block
      )

      define_singleton_method(:context) do
        context
      end

      define_singleton_method(:machine) do
        machine
      end
    end
  end
  
  # == Instance Methods =====================================================
  
  def initialize(input)
    @context =
      case (input)
      when Mua::State::Context
        input
      else
        self.class.context.new(input: input)
      end
    @machine = self.class.machine
  end

  def run!
    @machine.run!(@context)
  end

  def run
    @machine.run(@context)
  end
  alias_method :call, :run
end
