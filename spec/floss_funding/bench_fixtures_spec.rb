# frozen_string_literal: true

require_relative "../support/bench_gems_generator"

# Generate the 100 gem fixtures on disk (idempotent)
FlossFunding::BenchGemsGenerator.generate_all

RSpec.describe "Benchmark fixtures ENV segmentation" do # rubocop:disable RSpec/DescribeClass
  def remove_bench_constants
    (1..100).each do |i|
      mod_name = format("BenchGem%02d", i)
      Object.send(:remove_const, mod_name) if Object.const_defined?(mod_name) # rubocop:disable RSpec/RemoveConst
    end
    # Also remove the shared namespace used by gems 91..100, if present
    Object.send(:remove_const, :BenchGemShared) if Object.const_defined?(:BenchGemShared) # rubocop:disable RSpec/RemoveConst
  end

  def load_with_groups(enabled_groups)
    remove_bench_constants
    # Reset all group ENV vars to disabled (1..9 control the first 90 gems)
    (1..9).each { |g| ENV["FLOSS_FUNDING_FIXTURE_GROUP_#{g}"] = "0" }
    enabled_groups.each { |g| ENV["FLOSS_FUNDING_FIXTURE_GROUP_#{g}"] = "1" }
    load File.join(__dir__, "../fixtures/bench_gems_loader.rb")
  end

  def enabled_count
    (1..90).count do |i|
      mod = Object.const_get(format("BenchGem%02d", i))
      core = mod.const_get(:Core)
      core.respond_to?(:floss_funding_initiate_begging)
    end
  end

  it "enables exactly 10 fixtures when group 1 is enabled" do
    load_with_groups([1])
    expect(enabled_count).to eq(10)
  end

  it "enables exactly 20 fixtures when groups 1 and 2 are enabled" do
    load_with_groups([1, 2])
    expect(enabled_count).to eq(20)
  end

  it "enables exactly 90 fixtures when all 9 groups are enabled" do
    load_with_groups((1..9).to_a)
    expect(enabled_count).to eq(90)
  end

  context "when 10 fixture gems are enabled from group 1" do
    context "when load returns nil" do
      before do
        allow(Gem::Specification).to receive(:load).and_return(nil)
      end

      it "can recover" do
        load_with_groups([1])
        expect(enabled_count).to eq(10)
      end
    end

    context "when load returns a hash of bad data" do
      let(:bad_data) {
        {
          :name => "foo_bar",
          :authors => nil,
          :homepage => nil,
        }
      }
      let(:bad_spec) { instance_double(Gem::Specification, :metadata => {}, **bad_data) }

      before do
        allow(Gem::Specification).to receive(:load).and_return(bad_spec)
      end

      it "can handle it" do
        load_with_groups([1])
        expect(enabled_count).to eq(10)
      end
    end
  end
end
