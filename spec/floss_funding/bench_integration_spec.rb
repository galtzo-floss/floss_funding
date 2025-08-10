# frozen_string_literal: true

require "rspec/stubbed_env"
require "benchmark"
require_relative "../support/bench_gems_generator"

# Generate the 50 gem fixtures on disk (idempotent)
FlossFunding::BenchGemsGenerator.generate_all

RSpec.describe "Benchmark integration: Gemfile load with varying FlossFunding usage" do # rubocop:disable RSpec/DescribeClass
  # Remove any previously defined BenchGemXX constants to allow clean reloads
  def remove_bench_constants
    (1..50).each do |i|
      mod_name = format("BenchGem%02d", i)
      Object.send(:remove_const, mod_name) if Object.const_defined?(mod_name) # rubocop:disable RSpec/RemoveConst
    end
  end

  # Prepare ENV segmentation for a given percentage (0..100 in steps of 10)
  # 10 groups control 50 gems (5 per group). For percentage p, enable first g = p/10 groups.
  def set_percentage_env(percentage)
    raise ArgumentError, "percentage must be between 0 and 100" unless percentage.between?(0, 100)

    enabled_groups = (percentage / 10).to_i
    # Reset all to disabled
    (1..10).each { |g| ENV["FLOSS_FUNDING_FIXTURE_GROUP_#{g}"] = "0" }
    # Enable first N groups
    (1..enabled_groups).each { |g| ENV["FLOSS_FUNDING_FIXTURE_GROUP_#{g}"] = "1" }
  end

  # Counts how many of the 50 gems ended up including the Poke integration
  def enabled_count
    (1..50).count do |i|
      mod = Object.const_get(format("BenchGem%02d", i))
      core = mod.const_get(:Core)
      core.respond_to?(:floss_funding_initiate_begging)
    end
  end

  let(:loader_path) { File.join(__dir__, "../fixtures/bench_gems_loader.rb") }

  it "benchmarks load time across 0%..100% in 10% increments with ENV setup outside timing", :check_output do
    results = []

    (0..10).each do |step|
      percentage = step * 10
      # Ensure clean slate and set ENV segmentation BEFORE timing block
      remove_bench_constants
      set_percentage_env(percentage)

      # Now measure only the loading of the gems (simulating Gemfile load via our loader)
      elapsed = Benchmark.realtime do
        load loader_path
      end

      # Sanity check: the number of enabled gems matches the percentage (5 per 10%)
      expect(enabled_count).to eq(step * 5)

      results << { :percentage => percentage, :seconds => elapsed }
    end

    # We gathered 11 data points (0..100)
    expect(results.size).to eq(11)
    expect(results.all? { |r| r[:seconds].is_a?(Numeric) && r[:seconds] >= 0.0 }).to be(true)

    # Output the comparison table to spec output (not an assertion)
    formatted = results.map { |r| format("%3d%% => %.6fs", r[:percentage], r[:seconds]) }.join("\n")
    RSpec.configuration.reporter.message("FlossFunding bench (Gemfile load via fixtures):\n#{formatted}")
  end
end
