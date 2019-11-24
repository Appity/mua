module DebugMacros
  # NOTE: When adding methods to Active add a corresponding no-op method to
  #       Inactive or there will be errors when running in non-DEBUG mode.
  module Active
    def dtap
      $stdout.puts(caller[0])
      $stdout.puts(" => #{self.inspect}")

      self
    end

    def dins(*v)
      p *v
    end
  end

  module Inactive
    def dtap
      self
    end

    def dins
    end
  end
end

if (ENV['DEBUG'])
  $stdout.puts('Running with DEBUG mode enabled')
  Object.include(DebugMacros::Active)
  Kernel.extend(DebugMacros::Active)
else
  Object.include(DebugMacros::Inactive)
  Kernel.extend(DebugMacros::Inactive)
end
