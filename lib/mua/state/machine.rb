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

  # # Defines the initial state. Can be re-declared in subclasses or overridden
  # # with the class method initial_state(state)
  # def initial_state
  #   STATE_INITIAL_DEFAULT
  # end

  # # Enters the given state. Will call the appropriate leave_state trigger if
  # # one is defined for the previous state, and will trigger the callbacks for
  # # entry into the new state. If this state is set as a terminate state, then
  # # an immediate transition to the :terminate state will be performed after
  # # these callbacks.
  # def enter_state(state)
  #   if (@state)
  #     leave_state(@state)
  #   end
    
  #   @state = state

  #   delegate_call(:interpreter_entered_state, self, @state)
    
  #   trigger_callbacks(state, :enter)
    
  #   # :terminated is the state, :terminate is the trigger.
  #   if (@state != :terminated)
  #     if (trigger_callbacks(state, :terminate))
  #       enter_state(:terminated)
  #     end
  #   end
  # end
  
  # # Parses a given string and returns the first interpretable token, if any,
  # # or nil otherwise. If an interpretable token is found, the supplied string
  # # will be modified to have that matching portion removed.
  # def parse(buffer)
  #   instance_exec(buffer, &parser)
  # end
  
  # # Returns the parser defined for the current state, or the default parser.
  # # The default parser simply accepts everything but this can be re-defined
  # # using the class-level parse method.
  # def parser
  #   self.class.states.dig(@state, :parser) or self.class.default_parser
  # end

  # # Processes a given input string into interpretable tokens, processes these
  # # tokens, and removes them from the input string. An optional block can be
  # # given that will be called as each interpretable token is discovered with
  # # the token provided as the argument.
  # def process(s)
  #   _parser = parser

  #   while (parsed = instance_exec(s, &_parser))
  #     yield(parsed) if (block_given?)

  #     interpret(*parsed)

  #     break if (s.empty? or self.finished?)
  #   end
  # end
  
  # # Interprets a given object with an optional set of arguments. The actual
  # # interpretation should be defined by declaring a state with an interpret
  # # block defined.
  # def interpret(*args)
  #   object = args[0]
  #   interpreters = self.class.states.dig(@state, :interpret)

  #   if (interpreters)
  #     match_result = nil
      
  #     matched, proc = interpreters.find do |response, proc|
  #       case (response)
  #       when Regexp
  #         match_result = response.match(object)
  #       when Range
  #         response.include?(object)
  #       else
  #         response === object
  #       end
  #     end
    
  #     if (matched)
  #       case (matched)
  #       when Regexp
  #         match_result = match_result.to_a
        
  #         if (match_result.length > 1)
  #           match_result.shift
  #           args[0, 1] = match_result
  #         else
  #           args[0].sub!(match_result[0], '')
  #         end
  #       when String
  #         args[0].sub!(matched, '')
  #       when Range
  #         # Keep as-is
  #       else
  #         args.shift
  #       end
      
  #       # Specifying a block with no arguments will mean that it waits until
  #       # all pieces are collected before transitioning to a new state, 
  #       # waiting until the continue flag is false.
  #       will_interpret?(proc, args) and instance_exec(*args, &proc)

  #       return true
  #     end
  #   end
    
  #   if (trigger_callbacks(@state, :default, *args))
  #     # Handled by default
  #     true
  #   elsif (proc = self.class.default_interpreter)
  #     instance_exec(*args, &proc)
  #   else
  #     if (proc = self.class.on_error_handler)
  #       instance_exec(*args, &proc)
  #     end

  #     @error = "No handler for response #{object.inspect} in state #{@state.inspect}"
  #     enter_state(:terminated)

  #     false
  #   end
  # end
end
