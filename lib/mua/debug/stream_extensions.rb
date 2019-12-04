module Mua::Debug::StreamExtensions
  def blarg
    :blarg
  end

  def gets(*args)
    super.tap { |v| $stdout.puts('recv: %s' % v.inspect) }
  end

  def puts(*args, separator: $/)
    $stdout.puts('send: %s' % (args.length > 1 ? args.inspect : args[0].inspect))
    super
  end
end
