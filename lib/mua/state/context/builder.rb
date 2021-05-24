require_relative '../../struct'

class Mua::State::Context::Builder < Mua::Struct::Builder
  # == Constants ============================================================

  # == Extensions ===========================================================

  # == Class Methods ========================================================

  def self.class_with_attributes(attr_list, attr_spec, base_class = Mua::State::Context, &block)
    new(attr_list, attr_spec, base_class, &block).build
  end

  # == Instance Methods =====================================================

  # attr_list defines attributes with default behavior (read/write)
  # attr_spec can include options for each attribute:
  # * boolean: Generates x? interrogation method
  # * readonly: Omits generating mutator method
  # * convert: Conversion function to apply when writing
  def initialize(attr_list, attr_spec, base_class = Mua::State::Context, &block)
    @initial_state = attr_spec.delete(:initial_state)
    @terminal_states = attr_spec.delete(:terminal_states)

    super(attr_list, attr_spec, base_class, &block)
  end

  def build
    type = super

    if (@initial_state)
      define_initial_state!(type, @initial_state)
    end

    if (@terminal_states)
      define_terminal_states!(type, @terminal_states)
    end

    type
  end

  def define_initial_state!(type, initial_state)
    type.send(:define_singleton_method, :initial_state) do
      initial_state
    end

    type.send(:define_method, :initial_state) do
      initial_state
    end
  end

  def define_terminal_states!(type, terminal_states)
    type.send(:define_singleton_method, :terminal_states) do
      terminal_states
    end

    type.send(:define_method, :terminal_states) do
      terminal_states
    end
  end

  def define_initialize!(type, attrs)
    procs = self.attr_import_procs(attrs)

    type.send(:define_method, :initialize) do |reactor: nil, input: nil, iteration_limit: nil, **args|
      super(reactor: reactor, input: input, iteration_limit: iteration_limit)

      procs.each do |name, var, present, default|
        instance_variable_set(
          var,
          if (args.key?(name))
            present.call(args)
          else
            default.call(self)
          end
        )
      end

      yield(self) if (block_given?)
    end
  end
end
