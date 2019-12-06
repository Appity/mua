require_relative './token'

module Mua::Parser
  # == Module Methods =======================================================

  def self.read_stream(line: false, chomp: true, exactly: nil, partial: nil, match: nil, separator: $/, unpack: nil, &block)
    if (line)
      if (block)
        -> (context) do
          return if (context.input.eof?)

          block.call(context, context.input.gets(separator, chomp: chomp))

        rescue Async::TimeoutError
          block.call(Mua::Token::Timeout)
        end
      else
        -> (context) do
          return if (context.input.eof?)

          context.input.gets(separator, chomp: chomp)

        rescue Async::TimeoutError
          Mua::Token::Timeout
        end
      end
    elsif (match)
      if (block)
        -> (context) do
          return if (context.input.eof?)

          block.call(context, context.input.read_until(match, chomp: chomp))

        rescue Async::TimeoutError
          block.call(Mua::Token::Timeout)
        end
      else
        -> (context) do
          return if (context.input.eof?)

          context.input.read_until(match, chomp: chomp)

        rescue Async::TimeoutError
          Mua::Token::Timeout
        end
      end
    elsif (exactly)
      if (unpack)
        if (block)
          -> (context) do
            return if (context.input.eof?)
  
            block.call(context, *context.input.read_exactly(exactly).unpack(unpack))
  
          rescue Async::TimeoutError
            block.call(Mua::Token::Timeout)
          end
        else
          -> (context) do
            return if (context.input.eof?)
  
            context.input.read_exactly(exactly).unpack(unpack)
  
          rescue Async::TimeoutError
            Mua::Token::Timeout
          end
        end
      else
        if (block)
          -> (context) do
            return if (context.input.eof?)
  
            block.call(context, context.input.read_exactly(exactly))
  
          rescue Async::TimeoutError
            block.call(Mua::Token::Timeout)
          end
        else
          -> (context) do
            return if (context.input.eof?)
  
            context.input.read_exactly(exactly)
  
          rescue Async::TimeoutError
            Mua::Token::Timeout
          end
        end
      end
    elsif (block)
      block
    else
      raise DefinitionException, "Invalid specification for parse declaration, missing arguments."
    end
  end
end
