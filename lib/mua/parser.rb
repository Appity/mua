module Mua::Parser
  def self.read_stream(exactly: nil, partial: nil, match: nil, chomp: false, &block)
    if (block)
      block
    elsif (match)
      -> (s) do
        block.call(s.read_until(match, chomp: chomp))
      end
    elsif (exactly)
      -> (s) do
        block.call(s.read_exactly(exactly))
      end
    elsif (partial)
      -> (s) do
        block.call(s.read_exactly(partial))
      end
    else
      raise DefinitionException, "Invalid specification for parse declaration, missing arguments."
    end
  end
end
