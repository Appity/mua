require 'set'

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
  attr_reader :terminal_states
  attr_reader :terminal_state_default
  attr_reader :states

  # == Class Methods ========================================================

  # == Instance Methods =====================================================

  def initialize(name: nil, parent: nil, initial_state: nil, terminal_states: nil, auto_terminate: true)
    super(name: name, parent: parent, auto_terminate: auto_terminate) do
      @initial_state = initial_state || Mua::State::INITIAL_DEFAULT

      terminal_states =
        case (terminal_states)
        when Array
          terminal_states
        when Enumerable
          terminal_states.to_a
        when false
          [ ]
        when nil
          Mua::State::TERMINAL_DEFAULT
        else
          [ terminal_states ]
        end

      @terminal_states = Set.new(terminal_states)
      @terminal_state_default = terminal_states.first

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

        # Automatically terminate after this run if the state is terminal
        terminal = @terminal_states.include?(context.state)

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
        break if (step or context.terminated? or !transition or terminal)

      rescue Exception => e
        if (handler = @exception_handlers[e.class])
          handler.call(context, e)
        else
          # $stderr.puts('[%s] %s' % [ e.class, e ]) if (ENV['EXCEPTION_DEBUG'])

          raise e
        end
      end
    end
  end

protected
  def before_prepare
    interpret_states = @interpret.map(&:first)

    _initial_state = self.initial_state
    _terminal_state = self.terminal_state_default

    # NOTE: Use a manual search here to avoid caching an incomplete state list
    unless (interpret_states.include?(_initial_state))
      @interpret << [
        _initial_state,
        Mua::State.define(name: _initial_state, parent: self) do
          enter do |context|
            # Default behavior for an empty machine is to terminate
            context.transition!(state: _terminal_state)
          end
        end
      ]
    end

    # Create default terminal states
    (self.terminal_states.to_a - interpret_states).each do |terminal_state|
      @interpret << [
        terminal_state,
        Mua::State.define(name: terminal_state, parent: self) do
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
