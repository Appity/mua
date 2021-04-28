require_relative './token'

module Mua::Parser
  # == Module Methods =======================================================

  def self.read_stream(line: false, chomp: true, exactly: nil, partial: nil, match: nil, separator: $/, unpack: nil, &block)
    if (line)
      if (block)
        -> (context) do
          read = context.input.gets(separator, chomp: chomp).tap { |r| r&.chomp! if (chomp) }
          read and block.call(context, read)

        rescue EOFError
          nil
        rescue Async::TimeoutError
          block.call(context, Mua::Token::Timeout)
        end
      else
        -> (context) do
          context.input.gets(separator, chomp: chomp).tap { |r| r&.chomp! if (chomp) }

        rescue EOFError
          nil
        rescue Async::TimeoutError
          Mua::Token::Timeout
        end
      end
    elsif (match)
      if (block)
        -> (context) do
          read = context.input.read_until(match, chomp: chomp).tap { |r| r&.chomp! if (chomp) }
          read and block.call(context, read)

        rescue EOFError
          nil
        rescue Async::TimeoutError
          block.call(context, Mua::Token::Timeout)
        end
      else
        -> (context) do
          context.input.read_until(match, chomp: chomp).tap { |r| r&.chomp! if (chomp) }

        rescue Async::TimeoutError
          Mua::Token::Timeout
        end
      end
    elsif (exactly)
      if (unpack)
        if (block)
          -> (context) do
            read = context.input.read_exactly(exactly).tap { |r| r&.chomp! if (chomp) }
            read and block.call(context, *read.unpack(unpack))

          rescue EOFError
            nil
          rescue Async::TimeoutError
            block.call(context, Mua::Token::Timeout)
          end
        else
          -> (context) do
            context.input.read_exactly(exactly).tap { |r| r&.chomp! if (chomp) }.unpack(unpack)

          rescue EOFError
            nil
          rescue Async::TimeoutError
            Mua::Token::Timeout
          end
        end
      else
        if (block)
          -> (context) do
            read = context.input.read_exactly(exactly).tap { |r| r&.chomp! if (chomp) }
            read and block.call(context, read)

          rescue EOFError
            nil
          rescue Async::TimeoutError
            block.call(context, Mua::Token::Timeout)
          end
        else
          -> (context) do
            context.input.read_exactly(exactly).tap { |r| r&.chomp! if (chomp) }

          rescue EOFError
            nil
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
