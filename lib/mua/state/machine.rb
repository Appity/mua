require 'async'
require_relative '../state'

class Mua::State::Machine < Mua::State
  # == Constants ============================================================

  # == Exceptions ===========================================================

  class InvalidStateError < Mua::Error
  end
  
  # == Properties ===========================================================

  attr_reader :error

  attr_reader :initial_state
  attr_reader :final_state

  # == Class Methods ========================================================

  def self.define(name: nil, **options, &block)
    new(name, **options) do |state|
      Mua::State::Proxy.new(state, &block)
    end.tap(&:prepare)
  end

  # == Instance Methods =====================================================

  def initialize(name = nil, initial_state: nil, final_state: nil)
    super(name)

    @initial_state = initial_state || Mua::State::INITIAL_DEFAULT
    @final_state = final_state || Mua::State::FINAL_DEFAULT

    @default ||= -> (context, state, *_args) do
      raise InvalidStateError, 'Invalid state %s' % state.inspect
    end
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
    _initial_state = self.initial_state
    _final_state = self.final_state

    unless (state_defined?(_initial_state))
      @interpret << [
        _initial_state,
        -> (context) do
          context.transition!(state: _final_state)
        end
      ]
    end

    unless (state_defined?(_final_state))
      @interpret << [
        _final_state,
        -> (context) do
          context.terminated!
        end
      ]
    end
  end
end
