# frozen_string_literal: true

DEBUGGING = ENV.fetch("DEBUG", "false").casecmp("true").zero?

# External gems
require "debug" if DEBUGGING
require "silent_stream"
require "rspec/block_is_expected"
require "rspec/block_is_expected/matchers/not"
require "rspec/stubbed_env"

# Config files
require "config/timecop"
require "support/bench_gems_generator"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include(SilentStream)

  # Reset global FlossFunding state around each example to avoid cross-test pollution
  config.around do |example|
    begin
      # Snapshot state
      saved_namespaces = nil
      saved_silenced = nil
      if defined?(FlossFunding)
        saved_namespaces = FlossFunding.namespaces
        saved_silenced = FlossFunding.silenced
      end

      # Silence STDOUT for examples NOT tagged with :check_output
      if DEBUGGING || example.metadata[:check_output]
        example.run
      else
        silence_stream($stdout) do
          example.run
        end
      end
    ensure
      # Restore state
      if defined?(FlossFunding)
        FlossFunding.namespaces = saved_namespaces || {}
        FlossFunding.silenced = saved_silenced
      end
    end
  end
end

# Within the test suite, we will consider this gem to be activated
ENV["FLOSS_FUNDING_FLOSS_FUNDING"] = "Free-as-in-beer"

# NOTE: Gemfiles for older rubies won't have kettle-soup-cover.
#       The rescue LoadError handles that scenario.
begin
  require "kettle-soup-cover"
  require "simplecov" if Kettle::Soup::Cover::DO_COV # `.simplecov` is run here!
rescue LoadError => error
  # check the error message and re-raise when unexpected
  raise error unless error.message.include?("kettle")
end

require "floss_funding"
