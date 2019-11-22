class Mua::State
  # == Constants ============================================================

  INITIAL_DEFAULT = :initialize
  FINAL_DEFAULT = :finished

  # == Properties ===========================================================

  attr_reader :name

  attr_reader :parent

  attr_accessor :preprocess
  attr_accessor :parser
  attr_accessor :default
  attr_reader :enter
  attr_reader :leave
  attr_reader :interpret
  attr_reader :terminate

  # FIX: Add on_error or on_exception handlers

  # == Class Methods ========================================================

  def self.define(name: nil, &block)
    new(name) do |state|
      Mua::State::Proxy.new(state, &block)
    end.tap(&:prepare)
  end

  # == Instance Methods =====================================================
  
  # Creates a new state.
  def initialize(name = nil, parent: nil, prepare: true)
    @name = name
    @parent = parent

    @preprocess = nil
    @parser = nil
    @enter = [ ]
    @leave = [ ]
    @default = nil
    @interpret = [ ]
    @terminate = [ ]

    yield(self) if (block_given?)

    self.prepare unless (!prepare)
  end

  def prepare
    self.prepare_for_interpreter!

    self.dispatcher
    self.interpreter

    self
  end

  def interpreter_branches
    @interpret.reject do |_, v|
      v.is_a?(Mua::State)
    end
  end

  def interpreter
    @interpreter ||= Mua::State::Compiler.dispatcher(
      @interpret.reject do |_, v|
        v.is_a?(Mua::State)
      end,
      @default
    )
  end

  def dispatcher
    @dispatcher ||= Mua::State::Compiler.dispatcher(
      @interpret,
      @default
    )
  end

  def run!(context)
    self.run(context).to_a
  end

  def run(context)
    Enumerator.new do |events|
      terminated = false

      events << [ context, self, :enter ]

      case (result = self.trigger(context, @enter))
      when Mua::State::Transition
        # When a state transition occurs in the enter call, skip processing.
        context.state = result.state
      else
        case (result = @preprocess&.call(context))
        when Mua::State::Transition
          context.state = result.state
        else
          self.run_interior(events, context)
        end
      end

      events << [ context, self, :leave ]

      self.trigger(context, @leave)

      if (@terminate.any? or context.terminated?)
        events << [ context, self, :terminate ]

        self.trigger(context, @terminate)

        context.terminated! unless (context.terminated?)
      end
    end
  end
  alias_method :call, :run

  def run_interior(events, context)
    loop do
      branch, *args = @parser ? @parser.call(context) : context.read

      case (branch)
      when nil
        context.terminated!

        break
      when Mua::State::Transition
        context.state = branch.state

        break
      else
        case (result = self.dispatcher.call(context, branch, *args))
        when Mua::State::Transition
          context.state = result.state

          break
        when Enumerator
          result.each do |event|
            case (event)
            when Mua::State::Transition
              context.state = event.state

              break
            else
              events << event
            end
          end
        end
      end

      case (input = context.input)
      when Array
        break if (input.empty?)
      else
        break if (input.nil?)
      end

      break if (context.terminated?)
    end
  end

  def terminal?
    @terminate.any?
  end

  def arity
    method(:call).arity
  end

protected
  def dynamic_call(proc, context)
    return unless (proc)

    case (proc.arity)
    when 0
      proc.call
    when 1
      proc.call(context)
    else
      raise ArgumentError, "Handler proc should take 0..1 arguments."
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

  def prepare_for_interpreter!
    @default ||= @parent
  end
end

require_relative 'state/context'
require_relative 'state/compiler'
require_relative 'state/machine'
require_relative 'state/proxy'
require_relative 'state/transition'
