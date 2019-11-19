require 'async'
require_relative '../state'

class Mua::State::Machine < Mua::State
  # == Constants ============================================================

  STATE_INITIAL_DEFAULT = :initialize
  STATE_FINAL_DEFAULT = :finished

  # == Exceptions ===========================================================
  
  # == Properties ===========================================================

  attr_reader :error

  # == Class Methods ========================================================

  # == Instance Methods =====================================================

  def initialize(name = nil)
    super

    unless (state_defined?(STATE_INITIAL_DEFAULT))
      @interpret << [
        STATE_INITIAL_DEFAULT,
        -> (context) do
          context.transition!(state: STATE_FINAL_DEFAULT)
        end
      ]
    end

    # NOTE: Technically not necessary if another state is terminal.
    unless (state_defined?(STATE_FINAL_DEFAULT))
      @interpret << [
        STATE_FINAL_DEFAULT,
        -> (context) do
          context.terminated!
        end
      ]
    end
  end

  def state_defined?(state)
    @interpret.any? do |k, _p|
      k == state
    end
  end

  def states
    @interpret.map do |k, _p|
      k
    end
  end

  def state
    @__state ||= ->(name) { @interpret.find { |k, _p| k == name }&.dig(1) }
  end

  def run!(context = nil)
    self.call(context || Mua::State::Context.new).to_a
  end

  def run(context = nil)
    self.call(context || Mua::State::Context.new)
  end

  def call(context, *args)
    context.state ||= @interpret.dig(0, 0)

    Enumerator.new do |y|
      y << [ context, self, :enter ]

      self.trigger(context, @enter)

      until (context.terminated?)
        @parser and @parser.call(context, *args)

        state = context.state

        action = @interpret.find do |match, _proc|
          match === state
        end&.dig(1)

        unless (action)
          y << [ context, self, :error, :state_missing, state ]

          context.terminated!

          # FIX: Add on_error or on_missing_state handler?
          break
        end
        
        case (result = dynamic_call(action, context, *args))
        when Enumerator
          result.each do |event|
            case (event)
            when Mua::State::Transition
              context.state = event.state
              y << [ context, self, :transition, context.state ]
            else
              y << event
            end
          end
        when Mua::State::Transition
          context.state = result.state
          y << [ context, self, :transition, context.state ]
        end
      end

      y << [ context, self, :leave ]

      self.trigger(context, @leave)

      y << [ context, self, :terminate ]

      self.trigger(context, @terminate)
    end
  end
end
