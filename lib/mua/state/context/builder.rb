module Mua::State::Context::Builder
  # == Module Methods =======================================================

  def self.class_with_attributes(attr_list, attr_spec)
    type = Class.new(Mua::State::Context)

    if (initial_state = attr_spec.delete(:initial_state))
      define_initial_state!(type, initial_state)
    end

    includes = attr_spec.delete(:includes)

    attrs = remap_attrs(attr_list, attr_spec).map do |attr_name, attr_value|
      var = attr_value[:variable]

      if (attr_value[:boolean])
        define_boolean_attribute!(type, attr_name, var)
      elsif (attr_value[:readonly])
        define_readonly_attribute!(type, attr_name, var)
      else
        define_readwrite_attribute!(type, attr_name, var)
      end

      [ attr_name, attr_value ]
    end

    define_initialize!(type, attrs)

    case (includes)
    when Array
      includes.each do |i|
        type.include(i)
      end
    when Module
      type.include(includes)
    end

    type
  end

  def self.remap_attrs(attr_list, attr_spec, &block)
    remapped = attr_list.map do |attr_name|
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

      [ attr_name, attr_value ]
    end

    return remapped.to_h unless (block_given?)

    remapped.map(&block).to_h
  end

  def self.define_initial_state!(type, initial_state)
    type.send(:define_method, :initial_state) do
      initial_state
    end
  end

  def self.define_boolean_attribute!(type, attr_name, var)
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
  end

  def self.define_readonly_attribute!(type, attr_name, var)
    if ( :"@#{attr_name}" == var)
      type.send(:attr_reader, attr_name)
    else
      type.send(:define_method, attr_name) do
        instance_variable_get(var)
      end
    end
  end

  def self.define_readwrite_attribute!(type, attr_name, var)
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

  def self.define_initialize!(type, attrs)
    type.send(:define_method, :initialize) do |task: nil, state: nil, input: nil, **args|
      super(task: task, state: state, input: input)

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
  end
end
