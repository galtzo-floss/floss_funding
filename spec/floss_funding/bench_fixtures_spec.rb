# frozen_string_literal: true

require "rspec/stubbed_env"
require "floss_funding"
require_relative "../support/bench_gems_generator"

# Generate the 50 gem fixtures on disk (idempotent)
FlossFunding::BenchGemsGenerator.generate_all

RSpec.describe "Benchmark fixtures ENV segmentation" do # rubocop:disable RSpec/DescribeClass
  def remove_bench_constants
    (1..50).each do |i|
      mod_name = format("BenchGem%02d", i)
      Object.send(:remove_const, mod_name) if Object.const_defined?(mod_name) # rubocop:disable RSpec/RemoveConst
    end
  end

  def load_with_groups(enabled_groups)
    remove_bench_constants
    # Reset all group ENV vars to disabled
    (1..10).each { |g| ENV["FLOSS_FUNDING_FIXTURE_GROUP_#{g}"] = "0" }
    enabled_groups.each { |g| ENV["FLOSS_FUNDING_FIXTURE_GROUP_#{g}"] = "1" }
    load File.join(__dir__, "../fixtures/bench_gems_loader.rb")
  end

  def enabled_count
    (1..50).count do |i|
      mod = Object.const_get(format("BenchGem%02d", i))
      core = mod.const_get(:Core)
      core.respond_to?(:floss_funding_initiate_begging)
    end
  end

  it "enables exactly 5 fixtures when group 1 is enabled" do
    load_with_groups([1])
    expect(enabled_count).to eq(5)
  end

  it "enables exactly 10 fixtures when groups 1 and 2 are enabled" do
    load_with_groups([1, 2])
    expect(enabled_count).to eq(10)
  end

  it "enables exactly 50 fixtures when all 10 groups are enabled" do
    load_with_groups((1..10).to_a)
    expect(enabled_count).to eq(50)
  end
end
