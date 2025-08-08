# frozen_string_literal: true

# External gems
require "silent_stream"
require "rspec/block_is_expected"
require "rspec/block_is_expected/matchers/not"
begin
  require "rspec/stubbed_env"
rescue LoadError
  # ignore, we'll define a fallback below
end

# Provide a minimal fallback unless provided by the gem
unless defined?(stubbed_env)
  def stubbed_env(vars)
    raise ArgumentError, "stubbed_env expects a hash" unless vars.is_a?(Hash)
    saved = {}
    vars.each do |k, v|
      saved[k] = ENV.key?(k) ? ENV[k] : :__absent__
      v.nil? ? ENV.delete(k) : ENV[k] = v
    end
    begin
      yield
    ensure
      vars.each do |k, _|
        if saved[k] == :__absent__
          ENV.delete(k)
        else
          ENV[k] = saved[k]
        end
      end
    end
  end
end

# Config files
require "config/timecop"

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
