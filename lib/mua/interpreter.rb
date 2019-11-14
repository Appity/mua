require_relative 'state'

class Mua::Interpreter < Mua::State::Machine
  # == Constants ============================================================

  # == Exceptions ===========================================================
  
  # == Properties ===========================================================
  
  attr_reader :delegate

  # == Class Methods ========================================================

  # == Instance Methods =====================================================

  def initialize(context: nil, state: nil)
    @stream = stream
    @delegate = delegate
    @state = state || self.class.initial_state
    @error = nil
    
    yield(self) if (block_given?)
    
    enter_state(state)
  end

    # Returns the states that are defined as a has with their associated
  # options. The default keys are :initialized and :terminated.
  def states
    self.class.states_defined
  end

  def states_empty?
    self.states == Interpreter.states_defined
  end
  
  # Returns true if a given state is defined, false otherwise.
  def state_defined?(state)
    self.states.include?(state)
  end
  
  # Enters the given state. Will call the appropriate leave_state trigger if
  # one is defined for the previous state, and will trigger the callbacks for
  # entry into the new state. If this state is set as a terminate state, then
  # an immediate transition to the :terminate state will be performed after
  # these callbacks.
  def enter_state(state)
    if (@state)
      leave_state(@state)
    end
    
    @state = state

    delegate_call(:interpreter_entered_state, self, @state)
    
    trigger_callbacks(state, :enter)
    
    # :terminated is the state, :terminate is the trigger.
    if (@state != :terminated)
      if (trigger_callbacks(state, :terminate))
        enter_state(:terminated)
      end
    end
  end
  
  # Parses a given string and returns the first interpretable token, if any,
  # or nil otherwise. If an interpretable token is found, the supplied string
  # will be modified to have that matching portion removed.
  def parse(buffer)
    instance_exec(buffer, &parser)
  end
  
  # Returns the parser defined for the current state, or the default parser.
  # The default parser simply accepts everything but this can be re-defined
  # using the class-level parse method.
  def parser
    self.class.states.dig(@state, :parser) or self.class.default_parser
  end

  # Processes a given input string into interpretable tokens, processes these
  # tokens, and removes them from the input string. An optional block can be
  # given that will be called as each interpretable token is discovered with
  # the token provided as the argument.
  def process(s)
    _parser = parser

    while (parsed = instance_exec(s, &_parser))
      yield(parsed) if (block_given?)

      interpret(*parsed)

      break if (s.empty? or self.finished?)
    end
  end
  
  # Interprets a given object with an optional set of arguments. The actual
  # interpretation should be defined by declaring a state with an interpret
  # block defined.
  def interpret(*args)
    object = args[0]
    interpreters = self.class.states.dig(@state, :interpret)

    if (interpreters)
      match_result = nil
      
      matched, proc = interpreters.find do |response, proc|
        case (response)
        when Regexp
          match_result = response.match(object)
        when Range
          response.include?(object)
        else
          response === object
        end
      end
    
      if (matched)
        case (matched)
        when Regexp
          match_result = match_result.to_a
        
          if (match_result.length > 1)
            match_result.shift
            args[0, 1] = match_result
          else
            args[0].sub!(match_result[0], '')
          end
        when String
          args[0].sub!(matched, '')
        when Range
          # Keep as-is
        else
          args.shift
        end
      
        # Specifying a block with no arguments will mean that it waits until
        # all pieces are collected before transitioning to a new state, 
        # waiting until the continue flag is false.
        will_interpret?(proc, args) and instance_exec(*args, &proc)

        return true
      end
    end
    
    if (trigger_callbacks(@state, :default, *args))
      # Handled by default
      true
    elsif (proc = self.class.default_interpreter)
      instance_exec(*args, &proc)
    else
      if (proc = self.class.on_error_handler)
        instance_exec(*args, &proc)
      end

      @error = "No handler for response #{object.inspect} in state #{@state.inspect}"
      enter_state(:terminated)

      false
    end
  end
  
  # This method is used by interpret to determine if the supplied block should
  # be executed or not. The default behavior is to always execute but this
  # can be modified in sub-classes.
  def will_interpret?(proc, args)
    true
  end

  # Should return true if this interpreter no longer wants any data, false
  # otherwise. Subclasses should implement their own behavior here.
  def finished?
    false
  end
  
  # Returns true if an error has been generated, false otherwise. The error
  # content can be retrived by calling error.
  def error?
    !!@error
  end
  
protected
  def delegate_call(method, *args)
    @delegate and @delegate.respond_to?(method) and @delegate.send(method, *args)
  end
  
  def delegate_assign(property, value)
    method = :"#{property}="
    
    @delegate and @delegate.respond_to?(method) and @delegate.send(method, value)
  end

  def leave_state(state)
    trigger_callbacks(state, :leave)
  end
  
  def trigger_callbacks(state, type, *args)
    config = self.class.states[state]
    callbacks = (config and config[type])
    
    return unless (callbacks)

    callbacks.compact.each do |proc|
      instance_exec(*args, &proc)
    end
    
    true
  end
end
