class Mua::State::Proxy
  # == Constants ============================================================

  # == Instance Methods =====================================================
  
  # Attaches to a given State object. If a block is given, the block is
  # called in the context of this proxy object.
  def initialize(state, &proc)
    @state = state

    case (proc&.arity)
    when nil
      # Block is optional so skip calling it
    when 0
      instance_eval(&proc)
    when 1
      proc.call(self)
    else
      raise ArgumentError, "Block should take 0..1 arguments"
    end
  end
  
  # Defines a preprocessor that runs after the enter phase but before parse
  def preprocess(**spec, &proc)
    @state.preprocess = Mua::Parser.read_stream(**spec, &proc)
  end

  # Defines a parser specification.
  def parser(**spec, &proc)
    @state.parser = Mua::Parser.read_stream(**spec, &proc)
  end
  
  # Defines a proc that will execute when the state is entered.
  def enter(&proc)
    @state.enter << proc
  end
  
  # Defines an interpreter proc that will execute if the given response
  # condition is met.
  def interpret(response, &proc)
    @state.interpret << [ response, proc ]
  end

  # Defines a new state for a Mua::State::Machine
  def state(name, &block)
    Mua::State.new(name, parent: @state) do |state|
      state.parser = @state.parser

      Mua::State::Proxy.new(state, &block)

      @state.interpret << [ name, state ]
    end
  end
  
  # Defines a default behavior that will trigger in the event no interpreter
  # definition was triggered first.
  def default(&proc)
    @state.default = proc
  end

  # Defines a proc that will execute when the state is left.
  def leave(&proc)
    @state.leave << proc
  end
  
  # Terminates the interpreter after this state has been entered. Will execute
  # a proc if one is supplied.
  def terminate(&proc)
    @state.terminate << (proc || true)
  end
end
