# frozen_string_literal: true

RSpec.describe FlossFunding::ProjectRoot do
  describe "::path caches ::discover" do
    it "memoizes discovered path" do
      allow(described_class).to receive(:discover).and_return("/tmp/proj1")
      expect(described_class.path).to eq("/tmp/proj1")
      allow(described_class).to receive(:discover).and_return("/tmp/proj2")
      expect(described_class.path).to eq("/tmp/proj1")
      described_class.reset!
      expect(described_class.path).to eq("/tmp/proj2")
    end
  end

  describe "::discover delegates to ConfigFinder.project_root" do
    it "returns the project root from ConfigFinder" do
      allow(FlossFunding::ConfigFinder).to receive(:project_root).and_return("/x/y/z")
      expect(described_class.discover).to eq("/x/y/z")
    end
  end
end
