class Mua::State::Proxy
  # == Constants ============================================================

  # == Instance Methods =====================================================
  
  # Attaches to a given State object. If a block is given, the block is
  # called in the context of this proxy object.
  def initialize(state, &block)
    @state = state

    case (block&.arity)
    when nil
      # Block is optional so skip calling it
    when 1
      block.call(self)
    when 0
      instance_eval(&block)
    else
      raise ArgumentError, "Block should take 0..1 arguments"
    end
  end
  
  # Defines a parser specification.
  def parse(**spec, &block)
    @state.parser = Mua::Parser.read_stream(**spec, &block)
  end
  
  # Defines a block that will execute when the state is entered.
  def enter(&block)
    @state.enter << block
  end
  
  # Defines an interpreter block that will execute if the given response
  # condition is met.
  def interpret(response, &block)
    @state.interpret << [ response, block ]
  end
  
  # Defines a default behavior that will trigger in the event no interpreter
  # definition was triggered first.
  def default(&block)
    @state.default << block
  end

  # Defines a block that will execute when the state is left.
  def leave(&block)
    @state.leave << block
  end
  
  # Terminates the interpreter after this state has been entered. Will execute
  # a block if one is supplied.
  def terminate(&block)
    @state.terminate << (block || true)
  end
end
