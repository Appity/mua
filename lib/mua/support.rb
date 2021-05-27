module Mua::Support
  # == Constants ============================================================

  # == Extensions ===========================================================

  # == Module and Mixin Methods =============================================

  def stringify_keys(obj)
    case (obj)
    when Hash
      obj.map do |k, v|
        [ k&.to_s, stringify_keys(v) ]
      end.to_h
    when Array
      obj.map do |v|
        stringify_keys(v)
      end
    else
      obj
    end
  end

  def symbolize_keys(obj)
    case (obj)
    when Hash
      obj.map do |k, v|
        [ k&.to_sym, symbolize_keys(v) ]
      end.to_h
    when Array
      obj.map do |v|
        symbolize_keys(v)
      end
    else
      obj
    end
  end

  extend self
end
