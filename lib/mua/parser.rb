module Mua::Parser
  def self.read_stream(line: false, chomp: true, exactly: nil, partial: nil, match: nil, &block)
    if (line)
      if (block)
        -> (context) do
          return if (context.input.eof?)

          block.call(context, context.input.gets($/, chomp: chomp))
        end
      else
        -> (context) do
          return if (context.input.eof?)

          context.input.gets($/, chomp: chomp)
        end
      end
    elsif (match)
      if (block)
        -> (context) do
          return if (context.input.eof?)

          block.call(context, context.input.read_until(match, chomp: chomp))
        end
      else
        -> (context) do
          return if (context.input.eof?)

          context.input.read_until(match, chomp: chomp)
        end
      end
    elsif (exactly)
      if (block)
        -> (context) do
          return if (context.input.eof?)

          block.call(context, context.input.read_exactly(exactly))
        end
      else
        -> (context) do
          return if (context.input.eof?)

          context.input.read_exactly(exactly)
        end
      end
    elsif (partial)
      # REFACTOR: Determine which of partial and exactly are best suited
      # https://github.com/socketry/async-io/blob/master/lib/async/io/stream.rb
      if (block)
        -> (context) do
          return if (context.input.eof?)

          block.call(context, context.input.read_exactly(partial))
        end
      else
        -> (context) do
          return if (context.input.eof?)

          context.input.read_exactly(partial)
        end
      end
    elsif (block)
      block
    else
      raise DefinitionException, "Invalid specification for parse declaration, missing arguments."
    end
  end
end
