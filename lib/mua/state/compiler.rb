module Mua::State::Compiler
  # == Module Methods =======================================================

  # Creates a dispatch Proc that will branch to the appropriate handler
  def self.dispatcher(interpreters, default = nil)
    # REFACTOR: This should do a quick check on the blocks to ensure they take
    #           the required number of arguments.
    b = binding

    if (interpreters.any?)
      b.eval([
        '-> (context, branch, *args) do',
        'case (branch)',
        *interpreters.map.with_index do |(match, block), i|
          b.local_variable_set(:"__match_#{i}", block)

          case (match)
          when Regexp
            "when %s\n__match_%d.call(context, *$~, *args)" % [ match.inspect, i ]
          when Range
            "when %s\n__match_%d.call(context, branch, *args)" % [ match.inspect, i ]
          when String
            "when %s\n__match_%d.call(context, *args)" % [ match.dump, i ]
          when Symbol, Integer, Float, true, false, nil
            "when %s\n__match_%d.call(context, *args)" % [ match.inspect, i ]
          else
            raise "Unsupported branch type #{match.class}"
          end
        end,
        *(
          case (default)
          when Proc
            [ 'else', 'default.call(context, branch, *args)' ]
          when Mua::State
            [ 'else', 'default.interpreter(context, branch, *args)' ]
          when nil
            [ ]
          else
            raise "Unknown default class used: #{default.class}"
          end
        ),
        'end',
        'end'
      ].join("\n"))
    elsif (default)
      -> (context, branch, *args) do
        default.call(context, branch, *args)
      end
    else
      -> (context, branch, *args) { }
    end
  end
end
