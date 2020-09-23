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

  # == Instance Methods =====================================================

  def initialize(name: nil, parent: nil, initial_state: nil, final_state: nil, auto_terminate: true)
    super(name: name, parent: parent, auto_terminate: auto_terminate) do
      @initial_state = initial_state || Mua::State::INITIAL_DEFAULT
      @final_state = final_state || Mua::State::FINAL_DEFAULT

      yield(self) if (block_given?)

      @default ||= -> (context, state, *_args) do
        raise InvalidStateError, 'Invalid state %s in %s' % [ state.inspect, name || self.class ]
      end
    end
  end
  
  def state_defined?(state)
    @states.key?(state)
  end

  def run_interior(context, step: false, &events)
    loop do
      begin
        transition = nil

        unless (context.state)
          context.terminated!

          break
        end

        case (result = @dispatcher.call(context, context.state, &events))
        when Mua::State::Transition
          transition = result

          context.state = transition.state
          events&.call(context, self, :transition, context.state)

          break result.deparent! if (result.parent)
        end

        # Break if in single step mode, context has terminated, or the state
        # failed to transition to something else, which is a dead-end state
        # that would otherwise spin forever.
        break if (step or context.terminated? or !transition)

      rescue Exception => e
        if (handler = @exception_handlers[e.class])
          handler.call(context, e)
        else
          raise e
        end
      end
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
          leave do |context|
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
