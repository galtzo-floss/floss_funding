# frozen_string_literal: true

RSpec.describe FlossFunding::Config do
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
