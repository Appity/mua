class Mua::State
  # == Constants ============================================================

  # == Properties ===========================================================

  attr_reader :name

  attr_accessor :parser
  attr_accessor :default
  attr_reader :enter
  attr_reader :leave
  attr_reader :interpret
  attr_reader :terminate

  # == Instance Methods =====================================================
  
  # Creates a new state.
  def initialize(name = nil)
    @name = name
    @parser = nil
    @enter = [ ]
    @leave = [ ]
    @default = nil
    @interpret = [ ]
    @terminate = [ ]

    yield(self) if (block_given?)
  end

  def call(context, *args)
    branch, *args = @parser ? @parser.call(context, *args) : args

    Enumerator.new do |y|
      terminated = false

      y << [ context, self, :enter ]

      self.trigger(context, @enter)

      action = @interpret.find do |match, _proc|
        match === branch
      end&.dig(1) || default
      
      case (result = dynamic_call(action, context, *args))
      when Enumerator
        result.each do |event|
          y << event
        end
      end

      y << [ context, self, :leave ]

      self.trigger(context, @leave)

      if (@terminate.any? or context.terminated?)
        y << [ context, self, :terminate ]

        self.trigger(context, @terminate)

        context.terminated! unless (context.terminated?)
      end
    end
  end

  def terminal?
    @terminate.any?
  end

  def arity
    method(:call).arity
  end

protected
  def dynamic_call(proc, context, *args)
    return unless (proc)

    case (proc.arity)
    when 0
      proc.call
    when 1
      proc.call(context)
    else
      proc.call(context, *args)
    end
  end

  def trigger(context, procs)
    procs.each do |proc|
      case (proc)
      when true
        # No-op call, skipped
      when Proc
        case (proc.arity)
        when 0
          proc.call
        when 1
          proc.call(context)
        else
          raise ArgumentError, "Handler Proc should take 0 or 1 arguments."
        end
      else
        raise ArgumentError, "Non-Proc handler supplied."
      end
    end
  end
end

require_relative 'state/context'
require_relative 'state/machine'
require_relative 'state/proxy'
require_relative 'state/transition'
