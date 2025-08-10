# frozen_string_literal: true

require "rspec/stubbed_env"
require "benchmark"
require "floss_funding/under_bar"
require_relative "../support/bench_gems_generator"

# Generate the 100 gem fixtures on disk (idempotent)
FlossFunding::BenchGemsGenerator.generate_all

RSpec.describe "Benchmark integration: Gemfile load with varying FlossFunding usage" do # rubocop:disable RSpec/DescribeClass
  let(:valid_keys_csv) { File.join(__dir__, "../fixtures/valid_keys.csv") }
  let(:loader_path) { File.join(__dir__, "../fixtures/bench_gems_loader.rb") }

  # Parse CSV: returns array of hashes {namespace:, key_2025:, key_5425:}
  def parsed_keys(csv_path)
    rows = []
    File.readlines(csv_path, :chomp => true).each do |line|
      next if line.strip.empty?
      ns, k2025, k5425 = line.split(",", 3)
      rows << {:namespace => ns, :key_2025 => k2025, :key_5425 => k5425}
    end
    rows
  end

  # Returns ENV var name for a given namespace
  def env_var_for(ns)
    FlossFunding::UnderBar.env_variable_name(:namespace => ns)
  end

  # Compute which BenchGemXX namespaces are activated for percentage (first N*9 of 1..90)
  def activated_bench_namespaces_for_percentage(percentage)
    enabled_groups = (percentage / 10).to_i
    count = enabled_groups * 9
    (1..count).map { |i| format("BenchGem%02d", i) }
  end

  # Build env hash for stubbed_env for a given date scenario
  # key_type: :key_2025 or :key_5425
  def build_activation_env(keys_rows, percentage, key_type, unpaid: false)
    env = {}
    activated = activated_bench_namespaces_for_percentage(percentage)

    # First set all known namespaces in CSV to nil (unset)
    keys_rows.each do |row|
      env[env_var_for(row[:namespace])] = nil
    end

    # Then set only those that are activated to their respective key for the chosen era
    keys_rows.each do |row|
      if activated.include?(row[:namespace])
        env[env_var_for(row[:namespace])] = unpaid ? FlossFunding::FREE_AS_IN_BEER : row[key_type]
      end
    end

    env
  end

  # Remove any previously defined BenchGemXX constants to allow clean reloads
  def remove_bench_constants
    (1..100).each do |i|
      mod_name = format("BenchGem%02d", i)
      Object.send(:remove_const, mod_name) if Object.const_defined?(mod_name) # rubocop:disable RSpec/RemoveConst
    end
  end

  # Prepare ENV segmentation for a given percentage (0..100 in steps of 10)
  # 10 groups control 90 gems (9 per group). For percentage p, enable first g = p/10 groups.
  def set_percentage_env(percentage)
    raise ArgumentError, "percentage must be between 0 and 100" unless percentage.between?(0, 100)

    enabled_groups = (percentage / 10).to_i
    # Reset all to disabled
    (1..10).each { |g| ENV["FLOSS_FUNDING_FIXTURE_GROUP_#{g}"] = "0" }
    # Enable first N groups
    (1..enabled_groups).each { |g| ENV["FLOSS_FUNDING_FIXTURE_GROUP_#{g}"] = "1" }
  end

  # Counts how many of the 100 gems ended up including the Poke integration
  # For percentage tests, only the first 90 can be toggled by group ENV; final 10 remain disabled unless FINAL_10 is set.
  def enabled_count
    (1..100).count do |i|
      mod = Object.const_get(format("BenchGem%02d", i))
      core = mod.const_get(:Core)
      core.respond_to?(:floss_funding_initiate_begging)
    end
  end

  it "benchmarks load time across 0%..100% in 10% increments with ENV setup outside timing at 2025-08-15", :check_output do
    results = []
    keys_rows = parsed_keys(valid_keys_csv)

    Timecop.freeze(Time.local(2025, 8, 15, 12, 0, 0)) do
      (0..10).each do |step|
        percentage = step * 10
        # Ensure clean slate and set ENV segmentation BEFORE timing block
        remove_bench_constants
        set_percentage_env(percentage)

        activation_env = build_activation_env(keys_rows, percentage, :key_2025)

        stubbed_env(activation_env) do
          # Now measure only the loading of the gems (simulating Gemfile load via our loader)
          elapsed = Benchmark.realtime do
            load loader_path
          end

          # Sanity check: the number of enabled gems matches the percentage (9 per 10%)
          expect(enabled_count).to eq(step * 9)

          results << {:percentage => percentage, :seconds => elapsed}
        end
      end
    end

    # We gathered 11 data points (0..100)
    expect(results.size).to eq(11)
    expect(results.all? { |r| r[:seconds].is_a?(Numeric) && r[:seconds] >= 0.0 }).to be(true)

    # Output the comparison table to spec output (not an assertion)
    formatted = results.map { |r| format("%3d%% => %.6fs", r[:percentage], r[:seconds]) }.join("\n")
    RSpec.configuration.reporter.message("FlossFunding bench (Gemfile load via fixtures) at 2025-08-15:\n#{formatted}")
  end

  it "benchmarks load time across 0%..100% in 10% increments with ENV setup outside timing at 5425-07-15", :check_output do
    results = []
    keys_rows = parsed_keys(valid_keys_csv)

    # Note: For the far-future date, use the keys valid after 5425-07 (Column 3)
    Timecop.freeze(Time.local(5425, 7, 15, 12, 0, 0)) do
      (0..10).each do |step|
        percentage = step * 10
        remove_bench_constants
        set_percentage_env(percentage)

        activation_env = build_activation_env(keys_rows, percentage, :key_5425, :unpaid => true)

        stubbed_env(activation_env) do
          elapsed = Benchmark.realtime do
            load loader_path
          end

          expect(enabled_count).to eq(step * 9)
          results << {:percentage => percentage, :seconds => elapsed}
        end
      end
    end

    expect(results.size).to eq(11)
    expect(results.all? { |r| r[:seconds].is_a?(Numeric) && r[:seconds] >= 0.0 }).to be(true)

    formatted = results.map { |r| format("%3d%% => %.6fs", r[:percentage], r[:seconds]) }.join("\n")
    RSpec.configuration.reporter.message("FlossFunding bench (Gemfile load via fixtures) at 5425-07-15:\n#{formatted}")
  end
end
