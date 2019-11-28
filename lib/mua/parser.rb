require_relative './token'

module Mua::Parser
  # == Classes ==============================================================
  
  Redo = Mua::Token.new('Redo')
    # Used to indicate a parsing pass should be repeated.
  
  Timeout = Mua::Token.new('Timeout')

  # == Module Methods =======================================================

  def self.read_stream(line: false, chomp: true, exactly: nil, partial: nil, match: nil, separator: $/, &block)
    if (line)
      if (block)
        -> (context) do
          return if (context.input.eof?)

          block.call(context, context.input.gets(separator, chomp: chomp))

        rescue Async::TimeoutError
          block.call(Timeout)
        end
      else
        -> (context) do
          return if (context.input.eof?)

          context.input.gets(separator, chomp: chomp)

        rescue Async::TimeoutError
          Timeout
        end
      end
    elsif (match)
      if (block)
        -> (context) do
          return if (context.input.eof?)

          block.call(context, context.input.read_until(match, chomp: chomp))

        rescue Async::TimeoutError
          block.call(Timeout)
        end
      else
        -> (context) do
          return if (context.input.eof?)

          context.input.read_until(match, chomp: chomp)

        rescue Async::TimeoutError
          Timeout
        end
      end
    elsif (exactly)
      if (block)
        -> (context) do
          return if (context.input.eof?)

          block.call(context, context.input.read_exactly(exactly))

        rescue Async::TimeoutError
          block.call(Timeout)
        end
      else
        -> (context) do
          return if (context.input.eof?)

          context.input.read_exactly(exactly)

        rescue Async::TimeoutError
          Timeout
        end
      end
    elsif (partial)
      # REFACTOR: Determine which of partial and exactly are best suited
      # https://github.com/socketry/async-io/blob/master/lib/async/io/stream.rb
      if (block)
        -> (context) do
          return if (context.input.eof?)

          block.call(context, context.input.read_exactly(partial))

        rescue Async::TimeoutError
          block.call(Timeout)
        end
      else
        -> (context) do
          return if (context.input.eof?)

          context.input.read_exactly(partial)

        rescue Async::TimeoutError
          Timeout
        end
      end
    elsif (block)
      block
    else
      raise DefinitionException, "Invalid specification for parse declaration, missing arguments."
    end
  end
end
