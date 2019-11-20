require_relative 'state'

class Mua::Interpreter
  # == Constants ============================================================
  
  # == Extensions ===========================================================
  
  # == Properties ===========================================================
  
  # == Class Methods ========================================================

  def self.define(name, *attr_list, **attr_spec, &block)
    Class.new(Mua::Interpreter) do
      context = Mua::State::Context.with_attributes(*attr_list, **attr_spec)
      machine = Mua::State::Machine.define(name, &block)

      define_singleton_method(:context) do
        context
      end

      define_singleton_method(:machine) do
        machine
      end

      attr_reader :context
      attr_reader :machine

      def initialize(input)
        @context = self.class.context.new(input: input)
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
  end
  
  # == Instance Methods =====================================================
  
end
