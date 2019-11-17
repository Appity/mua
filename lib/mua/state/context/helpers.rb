module Mua::State::Context::Helpers
  # == Module Methods =======================================================

  def self.remap_attr_list_and_spec(attr_list, attr_spec, &block)
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
end
