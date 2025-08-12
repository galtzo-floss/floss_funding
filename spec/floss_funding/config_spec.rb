# frozen_string_literal: true

RSpec.describe FlossFunding::Config do
  describe "rescue paths" do
    it "returns empty hash from read_gemspec_data when Gem::Specification.load raises (rescued)" do
      allow(Dir).to receive(:glob).and_return(["/tmp/fake.gemspec"]) # ensure path discovered
      allow(Gem::Specification).to receive(:load).and_raise(StandardError)
      result = described_class.send(:read_gemspec_data, "/tmp")
      expect(result).to eq({})
    end
  end

  describe ".find_project_root delegation" do
    it "delegates to ConfigFinder.project_root" do
      allow(FlossFunding::ConfigFinder).to receive(:project_root).and_return("/tmp/proj")
      expect(described_class.find_project_root).to eq("/tmp/proj")
    end
  end

  describe "#normalize_to_array variants" do
    it "returns [] for nil" do
      expect(described_class.send(:normalize_to_array, nil)).to eq([])
    end

    it "returns compacted array for array input" do
      expect(described_class.send(:normalize_to_array, [1, nil, 2])).to eq([1, 2])
    end

    it "wraps scalar in array" do
      expect(described_class.send(:normalize_to_array, 7)).to eq([7])
    end
  end
end

RSpec.describe FlossFunding::ContraIndications do
  describe ".at_exit_contraindicated? variants" do
    it "returns true when any library provides a truthy callable value" do
      cfg = {
        "Lib::One" => {"silent" => [-> { true }]},
      }
      allow(FlossFunding).to receive(:configurations).and_return(cfg)
      expect(described_class.at_exit_contraindicated?).to be(true)
    end

    it "returns false when a callable raises an error (rescued)" do
      cfg = {
        "Lib::Two" => {"silent" => [-> { raise "boom" }]},
      }
      allow(FlossFunding).to receive(:configurations).and_return(cfg)
      expect(described_class.at_exit_contraindicated?).to be(false)
    end
  end
end
