module Mua::AttrBoolean
  def attr_boolean(name, default: false)
    var = :"@#{name}"
    define_method(:"#{name}?") do
      !!instance_variable_get(var)
    end

    define_method(:"#{name}=") do |val|
      instance_variable_set(var, !!val)
    end

    define_method(:"#{name}!") do |val = true|
      instance_variable_set(var, !!val)
    end
  end
end
