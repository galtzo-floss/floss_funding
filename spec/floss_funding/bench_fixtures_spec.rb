# frozen_string_literal: true

require_relative "../support/bench_gems_generator"

RSpec.describe "Benchmark fixtures ENV segmentation", :skip_ci do # rubocop:disable RSpec/DescribeClass
  def remove_bench_constants
    (1..100).each do |i|
      mod_name = format("BenchGem%02d", i)
      Object.send(:remove_const, mod_name) if Object.const_defined?(mod_name)
    end
  end

  def load_with_groups(enabled_groups)
    remove_bench_constants
    # Reset all group ENV vars to disabled (0..9 control the 100 gems)
    (0..9).each { |g| ENV["GEM_MINE_GROUP_#{g}"] = "0" }
    enabled_groups.each { |g| ENV["GEM_MINE_GROUP_#{g}"] = "1" }
    load File.join(__dir__, "../fixtures/bench_gems_loader.rb")
  end

  def enabled_count
    (1..100).count do |i|
      mod = Object.const_get(format("BenchGem%02d", i))
      core = mod.const_get(:Core)
      core.respond_to?(:floss_funding_fingerprint)
    end
  end

  it "enables exactly 10 fixtures when group 0 is enabled" do
    load_with_groups([0])
    expect(enabled_count).to eq(10)
  end

  it "enables exactly 20 fixtures when groups 0 and 1 are enabled" do
    load_with_groups([0, 1])
    expect(enabled_count).to eq(20)
  end

  it "enables exactly 100 fixtures when all 10 groups are enabled" do
    load_with_groups((0..9).to_a)
    expect(enabled_count).to eq(100)
  end

  context "when 10 fixture gems are enabled from group 0" do
    context "when load returns nil" do
      before do
        allow(Gem::Specification).to receive(:load).and_return(nil)
      end

      it "can recover" do
        load_with_groups([0])
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
        load_with_groups([0])
        expect(enabled_count).to eq(10)
      end
    end
  end
end
