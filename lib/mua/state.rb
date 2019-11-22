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

  attr_reader :interpreter
  attr_reader :dispatcher

  # FIX: Add on_error or on_exception handlers

  # == Class Methods ========================================================

  def self.define(name: nil, parent: nil, &block)
    new(name: name, parent: parent) do |state|
      Mua::State::Proxy.new(state, &block)
    end
  end

  # == Instance Methods =====================================================
  
  # Creates a new state.
  def initialize(name: nil, parent: nil, prepare: true)
    @name = name
    @parent = parent

    @preprocess = nil
    @parser = nil
    @enter = [ ]
    @leave = [ ]
    @default = nil
    @interpret = [ ]

    @prepared = false

    yield(self) if (block_given?)

    self.prepare if (prepare)
  end

  def prepare
    self.before_prepare

    @default ||= @parent

    @interpret.freeze

    @dispatcher = Mua::State::Compiler.dispatcher(
      @interpret,
      @default
    )

    @interpreter = Mua::State::Compiler.dispatcher(
      self.interpreter_branches,
      @default
    )

    @prepared = true

    self.after_prepare

    self
  end

  def prepared?
    @prepared
  end

  def interpreter_branches
    @interpret.reject do |_, v|
      v.is_a?(Mua::State)
    end
  end

  def run!(context)
    self.run(context).to_a
  end

  def run(context)
    Enumerator.new do |events|
      terminated = false

      events << [ context, self, :enter ]

      run = true

      case (result = self.trigger(context, @enter))
      when Mua::State::Transition
        # When a state transition occurs in the enter call, skip processing.
        context.state = result.state

        unless (result.parent === false)
          run = false
        end
      end

      if (run)
        case (result = @preprocess&.call(context))
        when Mua::State::Transition
          context.state = result.state
        else
          self.run_interior(events, context)
        end
      end

      events << [ context, self, :leave ]

      self.trigger(context, @leave)

      if (context.terminated? or !@parent)
        events << [ context, self, :terminate ]
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

        break unless (branch.parent === false)
      else
        case (result = @dispatcher.call(context, branch, *args))
        when Mua::State::Transition
          context.state = result.state

          break unless (result.parent === false)
        when Enumerator
          result.each do |event|
            case (event)
            when Mua::State::Transition
              context.state = event.state

              break unless (event.parent === false)
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
