require 'async'
require_relative '../state'

class Mua::State::Machine < Mua::State
  # == Constants ============================================================

  # == Exceptions ===========================================================
  
  # == Properties ===========================================================

  attr_reader :error

  # == Class Methods ========================================================

  # == Instance Methods =====================================================

  def initialize(name = nil)
    super
  end
  
  def state_defined?(state)
    @interpret.any? do |k, _p|
      state === k
    end
  end

  def states
    @interpret.map do |k, _p|
      k
    end
  end

  def initial_state
    @interpret.dig(0, 0)
  end

  def state
    @state_lookup ||= -> (name) { @interpret.find { |k, _p| k == name }&.dig(1) }
  end

  def run_interior(events, context)
    loop do
      unless (context.state)
        context.terminated!

        break
      end

      case (result = self.interpreter.call(context, context.state))
      when Mua::State::Transition
        context.state = result.state

        events << [ context, self, :transition, context.state ]
      when Enumerator
        result.each do |event|
          case (event)
          when Mua::State::Transition
            context.state = event.state

            events << [ context, self, :transition, context.state ]
          else
            events << event
          end
        end
      end

      break if (context.terminated?)
    end
  end

protected
  def prepare_for_interpreter!
    unless (state_defined?(Mua::State::INITIAL_DEFAULT))
      @interpret << [
        Mua::State::INITIAL_DEFAULT,
        -> (context) do
          context.transition!(state: Mua::State::FINAL_DEFAULT)
        end
      ]
    end

    # NOTE: Technically not necessary if another state is terminal.
    unless (state_defined?(Mua::State::FINAL_DEFAULT))
      @interpret << [
        Mua::State::FINAL_DEFAULT,
        -> (context) do
          context.terminated!
        end
      ]
    end
  end
end
