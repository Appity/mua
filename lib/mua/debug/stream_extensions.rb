module Mua::Debug::StreamExtensions
  def read(...)
    super.tap { |v| $stdout.puts('read: %s' % v.inspect) }
  end

  def read_partial(...)
    super.tap { |v| $stdout.puts('read_partial: %s' % v.inspect) }
  end

  def gets(...)
    super.tap { |v| $stdout.puts('gets: %s' % v&.chomp.inspect) }
  end

  def write(*args)
    $stdout.puts('write: %s' % (args.length > 1 ? args.inspect : args[0].inspect))
    super
  end

  def puts(*args, separator: $/)
    $stdout.puts('puts: %s' % (args.length > 1 ? args.inspect : args[0].inspect))
    super
  end
end
