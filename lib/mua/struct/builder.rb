class Mua::Struct::Builder
  # == Constants ============================================================

  # == Extensions ===========================================================

  # == Class Methods ========================================================

  def self.class_with_attributes(attr_list, attr_spec, base_class = Mua::Struct, &block)
    new(attr_list, attr_spec, base_class, &block).build
  end

  # == Instance Methods =====================================================

  # attr_list defines attributes with default behavior (read/write)
  # attr_spec can include options for each attribute:
  # * boolean: Generates x? interrogation method
  # * readonly: Omits generating mutator method
  # * convert: Conversion function to apply when writing
  def initialize(attr_list, attr_spec, base_class = Mua::Struct, &block)
    @attr_list = attr_list.dup
    @attr_spec = attr_spec.dup
    @base_class = base_class

    @block = block
  end

  def build
    type = Class.new(@base_class)

    includes = @attr_spec.delete(:includes)
    extends = @attr_spec.delete(:extends)

    attrs = @base_class.attr_map.merge(
      remap_attrs(@attr_list, @attr_spec).map do |attr_name, attr_value|
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

    visible_attrs = self.visible_attrs(attrs).freeze

    type.define_method(:to_h) do
      visible_attrs.transform_values do |v|
        instance_variable_get(v)
      end
    end
    type.alias_method(:as_json, :to_h)

    attributes = visible_attrs.keys.freeze

    type.define_singleton_method(:attributes) do
      attributes
    end

    type.define_method(:to_json) do |opts = nil|
      JSON.generate(self.as_json, opts)
    end

    @block and type.class_eval(&@block)

    type
  end

  def remap_attrs(attr_list, attr_spec, &block)
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

  def define_boolean_attribute!(type, attr_name, var)
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

  def visible_attrs(attrs)
    attrs.select do |name, meta|
      !(meta[:visible] === false)
    end.map do |name, meta|
      [ name, meta[:variable] ]
    end.to_h
  end

  def define_readonly_attribute!(type, attr_name, var)
    if (:"@#{attr_name}" == var)
      type.send(:attr_reader, attr_name)
    else
      type.send(:define_method, attr_name) do
        instance_variable_get(var)
      end
    end
  end

  def define_readwrite_attribute!(type, attr_name, var, convert_fn = nil)
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

  def attr_import_procs(attrs)
    attrs.map do |name, meta|
      [
        name,
        meta[:variable],
        if (meta[:convert])
          -> (args) { meta[:convert][args[name]] }
        else
          -> (args) { args[name] }
        end,
        case (default = meta[:default])
        when Proc
          case (default.arity)
          when 1
            default
          else
            -> (_struct) { default.call }
          end
        else
          -> (_struct) { default }
        end
      ]
    end
  end

  def define_initialize!(type, attrs)
    procs = self.attr_import_procs(attrs)

    type.send(:define_method, :initialize) do |**args, &block|
      super()

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
