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

    attrs = (
      attr_list.map do |attr_name|
        type.send(:attr_reader, attr_name)
        
        [ attr_name, { 
          variable: :"@#{attr_name}",
          default: nil
        } ]
      end + attr_spec.map do |attr_name, attr_value|
        defaults = {
          variable: :"@#{attr_name}",
          default: nil
        }

        case (attr_value)
        when Hash
          attr_value = defaults.merge(attr_value)
        else
          attr_value, default_value = defaults, attr_value
          attr_value[:default] = default_value
        end

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
        else
          if (defaults[:variable] == var)
            type.send(:attr_reader, attr_name)
          else
            type.send(:define_method, attr_name) do
              instance_variable_get(var)
            end
          end
        end

        [ attr_name, attr_value ]
      end
    ).to_h

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
end
