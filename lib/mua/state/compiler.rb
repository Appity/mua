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
        *interpreters.flat_map.with_index do |(match, block), i|
          b.local_variable_set(:"__block_#{i}", block)

          case (match)
          when Regexp
            [
              'when %s' % match.inspect,
              '__block_%d.call(context, *$~, *args)' % i
            ]
          when Range
            [
              'when %s' % match.inspect,
              '__block_%d.call(context, branch, *args)' % i
            ]
          when String
            [
              'when %s' % match.dump,
              '__block_%d.call(context, *args)' % i
            ] 
          when Symbol, Integer, Float, true, false, nil
            [
              'when %s' % match.inspect,
              '__block_%d.call(context, *args)' % i
            ]
          when Mua::Token
            mvar = :"__match_#{i}"
            b.local_variable_set(mvar, match)
            [
              'when %s' % mvar,
              '__block_%d.call(context, *args)' % i
            ]
          else
            raise "Unsupported branch type #{match.class}"
          end
        end,
        *(
          if (default)
            [ 'else', 'default.call(context, branch, *args)' ]
          else
            [ ]
          end
        ),
        'end',
        'rescue ArgumentError => e',
        'raise ArgumentError, "branch for input #{branch.inspect} has handler with #{e}"',
        'end'
      ].join("\n"))
    elsif (default)
      -> (context, branch, *args) do
        default.call(context, branch, *args)
      rescue ArgumentError => e
        raise ArgumentError, "default branch for input #{branch.inspect} has handler with #{e}"
      end
    else
      -> (context, branch, *args) { }
    end
  end
end
