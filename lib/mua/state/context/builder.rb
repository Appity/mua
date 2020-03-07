module Mua::State::Context::Builder
  # == Module Methods =======================================================

  # attr_list defines attributes with default behavior (read/write)
  # attr_spec can include options for each attribute:
  # * boolean: Generates x? interrogation method
  # * readonly: Omits generating mutator method
  # * convert: Conversion function to apply when writing
  def self.class_with_attributes(attr_list, attr_spec, base_class = Mua::State::Context)
    type = Class.new(base_class)

    if (initial_state = attr_spec.delete(:initial_state))
      define_initial_state!(type, initial_state)
    end

    if (final_state = attr_spec.delete(:final_state))
      define_final_state!(type, final_state)
    end

    includes = attr_spec.delete(:includes)
    extends = attr_spec.delete(:extends)

    attrs = base_class.attr_map.merge(
      remap_attrs(attr_list, attr_spec).map do |attr_name, attr_value|
        var = attr_value[:variable]

        if (attr_value[:boolean])
          define_boolean_attribute!(type, attr_name, var)
        elsif (attr_value[:readonly])
          define_readonly_attribute!(type, attr_name, var)
        else
          define_readwrite_attribute!(type, attr_name, var, attr_value[:convert])
        end

        [ attr_name, attr_value ]
      end.to_h
    )

    define_initialize!(type, attrs)

    type.class_eval do
      define_method(:attr_map) do
        attrs
      end
    end

    case (includes)
    when Array
      includes.each do |i|
        type.include(i)
      end
    when Module
      type.include(includes)
    end

    case (extends)
    when Array
      extends.each do |i|
        type.extend(i)
      end
    when Module
      type.extend(extends)
    end

    if (block_given?)
      type.class_eval(&Proc.new)
    end

    visible_attrs = attrs.select do |name, meta|
      !(meta[:visible] === false)
    end.map do |name, meta|
      [ name, meta[:variable] ]
    end.to_h

    visible_attrs[:state] = :@state

    type.define_method(:to_h) do
      visible_attrs.transform_values do |v|
        instance_variable_get(v)
      end
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
    type.send(:define_singleton_method, :initial_state) do
      initial_state
    end
    type.send(:define_method, :initial_state) do
      initial_state
    end
  end

  def self.define_final_state!(type, final_state)
    type.send(:define_singleton_method, :final_state) do
      final_state
    end
    type.send(:define_method, :final_state) do
      final_state
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

  def self.define_readwrite_attribute!(type, attr_name, var, convert_fn = nil)
    if (:"@#{attr_name}" == var and !convert_fn)
      type.send(:attr_accessor, attr_name)
    else
      type.send(:define_method, attr_name) do
        instance_variable_get(var)
      end
      if (convert_fn)
        type.send(:define_method, :"#{attr_name}=") do |v|
          instance_variable_set(var, convert_fn[v])
        end
      else
        type.send(:define_method, :"#{attr_name}=") do |v|
          instance_variable_set(var, v)
        end
      end
    end
  end

  def self.define_initialize!(type, attrs)
    type.send(:define_method, :initialize) do |reactor: nil, state: nil, input: nil, **args|
      super(reactor: reactor, state: state, input: input)

      if (initial_state = args[:state])
        @state = initial_state
      end

      attrs.each do |name, meta|
        if (args.key?(name))
          instance_variable_set(
            meta[:variable],
            meta[:convert] ? meta[:convert][args[name]] : args[name]
          )
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
