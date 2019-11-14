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

require_relative 'helpers/expect_mapping'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include ExpectMappingHelper
end

RSpec::Matchers.define :be_an_array_of do |expected|
  match do |actual|
    actual.map(&:class).uniq == [ expected ]
  end

  failure_message do |actual|
    "expected #{actual} to be composed of only #{expected} objects"
  end
end
