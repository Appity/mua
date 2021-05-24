require_relative 'constants'
require_relative 'token'

class Mua::Struct
  # == Constants ============================================================

  # == Extensions ===========================================================

  # == Properties ===========================================================

  # == Class Methods ========================================================

  def self.define(*attr_list, **attr_spec, &block)
    Mua::Struct::Builder.class_with_attributes(attr_list, attr_spec, self, &block)
  end

  def self.attr_map
    { }
  end

  # == Instance Methods =====================================================

  def initialize
    yield(self) if (block_given?)
  end
end

require_relative 'struct/builder'
