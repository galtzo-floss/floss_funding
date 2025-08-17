# frozen_string_literal: true

require "benchmark"
require_relative "../support/bench_gems_generator"

RSpec.describe "Benchmark integration: Gemfile load with varying FlossFunding usage", :skip_ci do # rubocop:disable RSpec/DescribeClass
  let(:valid_keys_csv) { File.join(__dir__, "../fixtures/valid_keys.csv") }
  let(:loader_path) { File.join(__dir__, "../fixtures/bench_gems_loader.rb") }

  include_context "with stubbed env"

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
    FlossFunding::UnderBar.env_variable_name(ns)
  end

  # Compute which namespaces are activated for a given percentage based on rules:
  # - 0% => none
  # - 10% => first 10 (BenchGem01..BenchGem10)
  # - 20%..100% => groups of 10 from the start, e.g., 30% => BenchGem01..BenchGem30
  def activated_bench_namespaces_for_percentage(percentage)
    case percentage
    when 0
      []
    else
      end_idx = percentage
      (1..end_idx).map { |i| format("BenchGem%02d", i) }
    end
  end

  # Build env hash for rspec-stubbed_env for a given date scenario
  # key_type: :key_2025 or :key_5425
  def build_activation_env(keys_rows, percentage, key_type, unpaid: false)
    activation_env = {}
    activated = activated_bench_namespaces_for_percentage(percentage)

    # First set all known namespaces in CSV to nil (unset)
    keys_rows.each do |row|
      activation_env[env_var_for(row[:namespace])] = nil
    end

    # Then set only those that are activated to their respective key for the chosen era
    keys_rows.each do |row|
      if activated.include?(row[:namespace])
        activation_env[env_var_for(row[:namespace])] = unpaid ? FlossFunding::FREE_AS_IN_BEER : row[key_type]
      end
    end

    activation_env
  end

  # Remove any previously defined BenchGemXX constants to allow clean reloads
  def remove_bench_constants
    (1..100).each do |i|
      mod_name = format("BenchGem%02d", i)
      Object.send(:remove_const, mod_name) if Object.const_defined?(mod_name)
    end
  end

  # Prepare ENV segmentation for a given percentage (0..100 in steps of 10)
  # GEM_MINE_GROUP_0..9, where number of enabled groups = percentage / 10
  def set_percentage_env(percentage)
    raise ArgumentError, "percentage must be between 0 and 100" unless percentage.between?(0, 100)

    # Reset all to disabled
    (0..9).each { |g| ENV["GEM_MINE_GROUP_#{g}"] = "0" }

    groups_to_enable = (percentage / 10)
    (0...[groups_to_enable, 10].min).each do |num|
      ENV["GEM_MINE_GROUP_#{num}"] = "1"
    end
  end

  # Counts how many of the 100 gems ended up including the Poke integration
  def enabled_count
    (1..100).count do |i|
      mod = Object.const_get(format("BenchGem%02d", i))
      core = mod.const_get(:Core)
      core.respond_to?(:floss_funding_fingerprint)
    end
  end

  def bench_step(step, keys_rows, results, key_type, options = {})
    percentage = step * 10
    # Ensure clean slate and set ENV segmentation BEFORE timing block
    remove_bench_constants
    set_percentage_env(percentage)

    activation_env = build_activation_env(keys_rows, percentage, key_type)

    stub_env(activation_env)

    # Now measure only the loading of the gems (simulating Gemfile load via our loader)
    elapsed = Benchmark.realtime do
      load loader_path
    end

    # Sanity check: since there are 100 gems, each 10% section should map to exactly 10 enabled gems
    expect(enabled_count).to eq(percentage)

    results << {:percentage => percentage, :seconds => elapsed}
  end

  it "benchmarks load time across 0%..100% in 10% increments (#{GLOBAL_DATE})" do
    results = []
    keys_rows = parsed_keys(valid_keys_csv)

    (0..10).each do |step|
      bench_step(step, keys_rows, results, :key_2025)
    end

    # We gathered 11 data points (0..100)
    expect(results.size).to eq(11)
    expect(results.all? { |r| r[:seconds].is_a?(Numeric) && r[:seconds] >= 0.0 }).to be(true)

    # Output the comparison table to spec output (not an assertion)
    formatted = results.map { |r| format("%3d%% => %.6fs", r[:percentage], r[:seconds]) }.join("\n")
    RSpec.configuration.reporter.message("FlossFunding bench (Gemfile load via fixtures) at 2025-08-15:\n#{formatted}")
  end

  it "benchmarks load time across 0%..100% in 10% increments with ENV setup outside timing at 5425-07-15", :freeze => Time.local(5425, 7, 15, 12, 0, 0) do
    results = []
    keys_rows = parsed_keys(valid_keys_csv)

    # Note: For the far-future date, use the keys valid after 5425-07 (Column 3)
    Timecop.freeze(Time.local(5425, 7, 15, 12, 0, 0)) do
      (0..10).each do |step|
        bench_step(step, keys_rows, results, :key_5425)
      end
    end

    expect(results.size).to eq(11)
    expect(results.all? { |r| r[:seconds].is_a?(Numeric) && r[:seconds] >= 0.0 }).to be(true)

    formatted = results.map { |r| format("%3d%% => %.6fs", r[:percentage], r[:seconds]) }.join("\n")
    RSpec.configuration.reporter.message("FlossFunding bench (Gemfile load via fixtures) at 5425-07-15:\n#{formatted}")
  end

  it "aggregates all available funded bench gem names after full percentage sweep (#{GLOBAL_DATE})" do
    keys_rows = parsed_keys(valid_keys_csv)

    (0..10).each do |step|
      percentage = step * 10
      remove_bench_constants
      set_percentage_env(percentage)
      activation_env = build_activation_env(keys_rows, percentage, :key_2025)
      stub_env(activation_env)
      load loader_path
    end

    # Determine which BenchGem namespaces actually have keys available in the CSV
    bench_names = (1..100).map { |i| format("BenchGem%02d", i) }
    csv_names = keys_rows.map { |r| r[:namespace] }
    expected_bench_activated = bench_names & csv_names

    # Activated namespaces collected by the library (includes FlossFunding itself)
    activated = FlossFunding.all_namespaces.map(&:name)

    # Assert that all bench gems for which we have keys became activated during the sweep
    expect((activated & expected_bench_activated).size).to eq(expected_bench_activated.size)
  end
end
