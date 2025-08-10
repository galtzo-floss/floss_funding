# frozen_string_literal: true

# External gems
require "debug"
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

  # Silence STDOUT for examples NOT tagged with :check_output
  config.around do |example|
    if example.metadata[:check_output]
      example.run
    else
      silence_stream($stdout) do
        example.run
      end
    end
  end
end

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
