# frozen_string_literal: true

RSpec.describe FlossFunding::ConfigLoader do
  describe ".load_file" do
    it "returns empty hash when an unexpected error occurs (rescued)" do
      allow(File).to receive(:read).and_raise(StandardError)
      expect(described_class.load_file("/tmp/anything.yml")).to eq({})
    end

    it "raises ConfigNotFoundError when file does not exist" do
      expect {
        described_class.load_file("/definitely/missing.yml")
      }.to raise_error(FlossFunding::ConfigNotFoundError)
    end
  end

  describe ".configuration_file_for" do
    it "delegates to ConfigFinder.find_config_path" do
      allow(FlossFunding::ConfigFinder).to receive(:find_config_path).with("/tmp/dir").and_return("/x.yml")
      expect(described_class.configuration_file_for("/tmp/dir")).to eq("/x.yml")
    end
  end

  describe ".default_configuration" do
    it "loads defaults as a Hash" do
      cfg = described_class.default_configuration
      expect(cfg).to be_a(Hash)
      expect(cfg).to include("funding_subscription_uri", "suggested_subscription_amounts", "funding_donation_uri", "suggested_donation_amounts")
    end

    it "memoizes across calls until reset_caches! is invoked" do
      first = described_class.default_configuration
      second = described_class.default_configuration
      expect(first.object_id).to eq(second.object_id)
      expect(first).to be_frozen

      described_class.reset_caches!

      third = described_class.default_configuration
      expect(third).to be_a(Hash)
      expect(third.object_id).not_to eq(first.object_id)
      expect(third).to be_frozen
    end
  end
end
