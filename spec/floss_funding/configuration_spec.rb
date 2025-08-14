# frozen_string_literal: true

RSpec.describe FlossFunding::Configuration do
  describe ".merged_config" do
    it "returns empty Configuration when given empty input" do
      merged = described_class.merged_config([])
      expect(merged).to be_a(described_class)
      expect(merged).to be_empty
      expect(merged.size).to eq(0)
    end

    it "merges multiple configurations and skips non-enumerable entries" do
      cfg1 = described_class.new({"a" => 1, :b => [2]})
      cfg2 = described_class.new({"a" => [3], :c => 4})
      merged = described_class.merged_config([cfg1, Object.new, cfg2])
      expect(merged["a"]).to eq([1, 3])
      expect(merged["b"]).to eq([2])
      expect(merged["c"]).to eq([4])
    end
  end

  describe "#fetch variants" do
    let(:cfg) { described_class.new({"x" => 1}) }

    it "returns value for existing key" do
      expect(cfg.fetch("x", :default)).to eq([1])
    end

    it "yields block for missing key" do
      yielded = nil
      result = cfg.fetch("y") { |k|
        yielded = k
        :block_default
      }
      expect(yielded).to eq("y")
      expect(result).to eq(:block_default)
    end

    it "returns provided default for missing key when no block" do
      expect(cfg.fetch("y", :default)).to eq(:default)
    end
  end

  describe "#each enumerator" do
    it "returns an enumerator when no block is given" do
      cfg = described_class.new({"a" => 1})
      enum = cfg.each
      expect(enum).to be_an(Enumerator)
      expect(enum.to_a).to eq([["a", [1]]])
    end
  end

  describe "#key? and aliases" do
    it "checks presence of keys" do
      cfg = described_class.new({:a => 1})
      expect(cfg.key?("a")).to be(true)
      expect(cfg.include?(:a)).to be(true)
      expect(cfg.has_key?("missing")).to be(false)
    end
  end

  describe "#to_h/#size/#empty?" do
    it "returns dup of internal data and reports size/empty" do
      cfg = described_class.new({:a => 1})
      h = cfg.to_h
      expect(h).to eq({"a" => [1]})
      expect(h).not_to be(cfg.instance_variable_get(:@data))
      expect(cfg.size).to eq(1)
      expect(cfg.empty?).to be(false)
    end
  end

  describe "#keys" do
    it "returns stringified keys" do
      cfg = described_class.new({:a => 1, "b" => [2]})
      expect(cfg.keys.sort).to eq(["a", "b"])
    end
  end

  describe "#[] normalization when value is nil" do
    it "normalizes nil values to empty arrays via the public API" do
      cfg = described_class.new({:a => nil})
      expect(cfg["a"]).to eq([])
    end
  end
end
