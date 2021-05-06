require_relative 'state'

class Mua::Interpreter
  # == Constants ============================================================

  # == Extensions ===========================================================

  # == Properties ===========================================================

  attr_reader :context
  attr_reader :machine

  # == Class Methods ========================================================

  def self.define(*attr_list, name: nil, context: nil, **attr_spec, &block)
    Class.new(Mua::Interpreter) do
      context ||= Mua::State::Context.define(
        *attr_list,
        **attr_spec
      )
      machine = Mua::State::Machine.define(
        name: name,
        **attr_spec.slice(:initial_state, :terminal_states),
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
    @machine = self.class.machine
    @context =
      case (input)
      when Mua::State::Context
        input
      else
        self.class.context.new(
          input: input,
          state: @machine.initial_state
        )
      end

    yield(self) if (block_given?)
  end

  def run(&block)
    @machine.run(@context, &block)
  end
  alias_method :call, :run
end
