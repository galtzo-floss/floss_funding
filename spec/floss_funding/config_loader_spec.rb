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

  describe ".default_configuration" do
    it "loads defaults as a Hash" do
      cfg = described_class.default_configuration
      expect(cfg).to be_a(Hash)
      expect(cfg).to include("suggested_donation_amount", "floss_funding_url")
    end
  end
end
