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

  # FIX: Add on_error or on_exception handlers

  # == Class Methods ========================================================

  def self.define(name = nil, &block)
    new(name) do |state|
      Mua::State::Proxy.new(state, &block)
    end
  end

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

      case (result = self.trigger(context, @enter))
      when Mua::State::Transition
        # When a state transition occurs in the enter call, skip processing.
        context.state = result.state
      else
        action = @interpret.find do |match, _proc|
          match === branch
        end&.dig(1) || default
        
        case (result = dynamic_call(action, context, *args))
        when Enumerator
          result.each do |event|
            y << event
          end
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
    procs.inject(nil) do |_, proc|
      case (result = trigger_call(context, proc))
      when Mua::State::Transition
        break result
      else
        result
      end
    end
  end
end

def trigger_call(context, proc)
  case (proc)
  when true
    # No-op call, skipped
  when Proc
    case (proc.arity)
    when 0
      context.instance_eval(&proc)
    when 1
      proc.call(context)
    else
      raise ArgumentError, "Handler Proc should take 0 or 1 arguments."
    end
  else
    raise ArgumentError, "Non-Proc handler supplied."
  end
end

require_relative 'state/context'
require_relative 'state/machine'
require_relative 'state/proxy'
require_relative 'state/transition'
