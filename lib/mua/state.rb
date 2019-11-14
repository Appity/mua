class Mua::State
  # == Constants ============================================================

  # == Properties ===========================================================

  attr_reader :name

  attr_accessor :parser
  attr_reader :enter
  attr_reader :leave
  attr_reader :default
  attr_reader :interpret
  attr_reader :terminate

  # == Instance Methods =====================================================
  
  # Creates a new state.
  def initialize(name = nil)
    @name = name
    @parser = nil
    @enter = [ ]
    @leave = [ ]
    @default = [ ]
    @interpret = [ ]
    @terminate = [ ]
  end

  def execute(context, *args)
    args = @parser ? @parser[context, *args] : args

    Enumerator.new do |y|
      y << context
    end
  end

  def terminal?
    @terminate.any?
  end
end

require_relative 'state/context'
require_relative 'state/machine'
require_relative 'state/proxy'
