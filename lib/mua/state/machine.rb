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
  attr_reader :states

  # == Class Methods ========================================================

  def self.define(name: nil, **options, &block)
    new(name: name, **options) do |state|
      Mua::State::Proxy.new(state, &block)
    end
  end

  # == Instance Methods =====================================================

  def initialize(name: nil, parent: nil, initial_state: nil, final_state: nil)
    super(name: name, parent: parent) do
      @initial_state = initial_state || Mua::State::INITIAL_DEFAULT
      @final_state = final_state || Mua::State::FINAL_DEFAULT

      yield(self) if (block_given?)

      @default ||= -> (context, state, *_args) do
        raise InvalidStateError, 'Invalid state %s' % state.inspect
      end  
    end
  end
  
  def state_defined?(state)
    @states.key?(state)
  end

  def run_interior(events, context)
    loop do
      unless (context.state)
        context.terminated!

        break
      end

      case (result = @dispatcher.call(context, context.state))
      when Mua::State::Transition
        context.state = result.state

        events << [ context, self, :transition, context.state ]

        break if (event.parent)
      when Enumerator
        result.each do |event|
          case (event)
          when Mua::State::Transition
            context.state = event.state

            events << [ context, self, :transition, context.state ]

            break if (event.parent)
          else
            events << event
          end
        end
      end

      break if (context.terminated?)
    end
  end

protected
  def before_prepare
   _initial_state = self.initial_state
    _final_state = self.final_state

    # NOTE: Use a manual search here to avoid caching an incomplete state list
    unless (@interpret.any? { |n, _| n == _initial_state })
      @interpret << [
        _initial_state,
        Mua::State.define(name: _initial_state, parent: self) do
          enter do |context|
            context.transition!(state: _final_state)
          end
        end
      ]
    end

    unless (@interpret.any? { |n, _| n == _final_state })
      @interpret << [
        _final_state,
        Mua::State.define(name: _final_state, parent: self) do
          enter do |context|
            context.terminated!
          end
        end
      ]
    end
  end

  def after_prepare
    @states = @interpret.select do |_n, s|
      s.is_a?(Mua::State)
    end.to_h.freeze
  end
end
