require 'bundler/setup'
require 'mua'
require 'yaml'

require 'async'
require 'async/io'
require 'async/rspec'

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

require_relative 'helpers/debug_macros'

require_relative 'helpers/expect_mapping'
require_relative 'helpers/interpreter_debug_log'
require_relative 'helpers/simulate_exchange'
require_relative 'helpers/state_events_helper'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include(ExpectMappingHelper)
  config.include(SimulateExchange, type: :interpreter)
  config.include(InterpreterDebugLog, type: :interpreter)
  config.include_context(Async::RSpec::Reactor, type: :reactor)

  if (ENV['DEBUG'])
    puts 'Stream debugging enabled'
    Async::IO::Stream.prepend(Mua::Debug::StreamExtensions)

    config.include_context(Async::RSpec::Leaks, type: :reactor_leaks)
  end
end

RSpec::Matchers.define :be_an_array_of do |expected|
  match do |actual|
    actual.map(&:class).uniq == [ expected ]
  end

  failure_message do |actual|
    "expected #{actual} to be composed of only #{expected} objects"
  end
end

Signal.trap('USR1') do
  Thread.list.each do |t|
    p t
    puts t.backtrace.join("\n")
  end
end
