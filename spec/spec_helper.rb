require 'bundler/setup'
require 'mua'

module TestTriggerHelper
  def self.included(base)
    base.class_eval do
      def triggered
        @triggered ||= Hash.new(false)
      end
      
      def trigger(action, value = true)
        self.triggered[action] = value
      end
    end
  end
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
