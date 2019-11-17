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

  def self.with_attributes(*attr_list, **attr_spec)
    type = Class.new(self)

    attrs = Helpers.remap_attr_list_and_spec(attr_list, attr_spec).map do |attr_name, attr_value|
      var = attr_value[:variable]

      if (attr_value[:boolean])
        type.send(:define_method, :"#{attr_name}?") do
          instance_variable_get(var)
        end

        type.send(:define_method, :"#{attr_name}=") do |v|
          instance_variable_set(var, !!v)
        end

        type.send(:define_method, :"#{attr_name}!") do |&block|
          return false if (instance_variable_get(var))

          block&.call

          instance_variable_set(var, true)
        end
      elsif (attr_value[:readonly])
        if ( :"@#{attr_name}" == var)
          type.send(:attr_reader, attr_name)
        else
          type.send(:define_method, attr_name) do
            instance_variable_get(var)
          end
        end
      else
        if (:"@#{attr_name}" == var)
          type.send(:attr_accessor, attr_name)
        else
          type.send(:define_method, attr_name) do
            instance_variable_get(var)
          end
          type.send(:define_method, :"#{attr_name}=") do |v|
            instance_variable_set(var, v)
          end
        end
      end

      [ attr_name, attr_value ]
    end.to_h

    type.send(:define_method, :initialize) do |**args|
      super()

      attrs.each do |name, meta|
        if (args.key?(name))
          instance_variable_set(meta[:variable], args[name])
        else
          instance_variable_set(
            meta[:variable],
            case (default = meta[:default])
            when Proc
              default.call
            else
              default
            end
          )
        end
      end
    end

    type
  end
  
  # == Instance Methods =====================================================

  def initialize(task: nil, state: nil)
    @task = task
    @state = state
    @terminated = false
  end

  def transition!(target: nil, state:)
    Mua::State::Transition.new(target: target, state: state)
  end

  def finished!
    Mua::State::Transition.new(state: :finished)
  end
end

require_relative 'context/helpers'