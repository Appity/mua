require_relative 'token'

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
  attr_reader :rescue_from

  attr_reader :interpreter
  attr_reader :dispatcher

  # FIX: Add on_error or on_exception handlers

  # == Class Methods ========================================================

  def self.define(name: nil, parent: nil, auto_terminate: true, **options, &block)
    new(name: name, parent: parent, auto_terminate: auto_terminate, **options) do |state|
      Mua::State::Proxy.new(state, &block)
    end
  end

  # == Instance Methods =====================================================
  
  # Creates a new state.
  def initialize(name: nil, parent: nil, prepare: true, auto_terminate: true)
    @name = name
    @parent = parent

    @preprocess = nil
    @parser = nil
    @enter = [ ]
    @leave = [ ]
    @default = nil
    @interpret = [ ]
    @rescue_from = [ ]

    @prepared = false
    @auto_terminate = !!auto_terminate

    yield(self) if (block_given?)

    self.prepare if (prepare)
  end

  def prepare
    return if (@prepared)

    self.before_prepare

    @default ||= @parent&.interpreter

    @interpret.freeze

    @dispatcher = Mua::State::Compiler.dispatcher(
      interpreters: @interpret,
      rescue_from: @rescue_from,
      default: @default
    )

    @interpreter = Mua::State::Compiler.dispatcher(
      interpreters: self.interpreter_branches,
      rescue_from: @rescue_from,
      default: @default
    )

    @exception_handlers = @rescue_from.to_h

    @prepared = true

    @interpret.map do |_m, b|
      b.prepare if (b.respond_to?(:prepare))
    end

    self.after_prepare

    self.freeze
  end

  def auto_terminate?
    @auto_terminate
  end

  def prepared?
    @prepared
  end

  def interpreter_branches
    @interpret.reject do |_, v|
      v.is_a?(Mua::State)
    end
  end

  def run(context, step: false, &events)
    # REFACTOR: This needs to be something the Compiler can generate
    terminated = false
    transition = nil

    events&.call(context, self, :enter)

    case (result = self.trigger(context, @enter))
    when Mua::State::Transition
      # When a state transition occurs in the enter call, skip processing.
      context.state = result.state

      unless (result.parent === false)
        transition = result
      end
    end

    unless (transition)
      case (result = @preprocess&.call(context))
      when Mua::State::Transition
        context.state = result.state
      else
        case (iresult = self.run_interior(context, step: step, &events))
        when Mua::State::Transition
          transition = iresult
        end
      end
    end

    events&.call(context, self, :leave)

    self.trigger(context, @leave)

    if (context.terminated? or (!@parent and @auto_terminate))
      events&.call(context, self, :terminate)
    end

    transition

  rescue Exception => e
    if (handler = @exception_handlers[e.class])
      handler.call(context, e)
    else
      raise e
    end
  end
  alias_method :call, :run

  def run_interior(context, step: false, &events)
    # REFACTOR: This needs to be something the Compiler can generate
    loop do
      begin
        branch, *args = @parser&.call(context)
        
        redo if (branch == Mua::Token::Redo)
      end

      if (branch)
        events&.call(context, self, :branch, branch)
      end

      run = true

      case (branch)
      when Mua::State::Transition
        context.state = branch.state

        break branch unless (branch.parent === false)

        branch = context.state
      when nil
        context.terminated! if (self.auto_terminate?)
        break
      end

      if (run)
        case (result = @dispatcher.call(context, branch, *args, &events))
        when Mua::State::Transition
          context.state = result.state

          break result unless (result.parent === false)
        end
      end

      break if (step or context.terminated?)
    end

  rescue Async::Wrapper::Cancelled
    context.terminated!
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

  def before_prepare
    # Override in subclasses
  end

  def after_prepare
    # Override in subclasses
  end
end

require_relative 'state/context'
require_relative 'state/compiler'
require_relative 'state/machine'
require_relative 'state/proxy'
require_relative 'state/transition'
