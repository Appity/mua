module InterpreterDebugLog
  def interpreter_run!(interpreter)
    if (ENV['DEBUG'])
      interpreter_debug_log!(interpreter)
    else
      interpreter.run
    end
  end
  
  def interpreter_debug_log!(interpreter)
    interpreter.run do |context, state, *event|
      if (state.name == state.class.to_s)
        $stdout.puts("#{state.class} -> #{event.inspect}")
      else
        $stdout.puts("#{state.class}(#{state.name}) -> #{event.inspect}")
      end
    end
  end

  extend self
end
