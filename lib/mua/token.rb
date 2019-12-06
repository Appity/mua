class Mua::Token
  # == Constants ============================================================

  # == Extensions ===========================================================
  
  # == Properties ===========================================================

  attr_reader :name
  
  # == Class Methods ========================================================
  
  # == Instance Methods =====================================================
  
  def initialize(name)
    @name = name
  end

  def inspect
    "<Mua::Token(#{@name})>"
  end

  def hash
    @name.hash
  end

  def eql?(token)
    self.object_id == token.object_id
  end

  # == Pre-Defined Tokens ===================================================

  Redo = new('Redo')
  Timeout = new('Timeout')
end
