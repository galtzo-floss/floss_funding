# frozen_string_literal: true

RSpec.describe FlossFunding::ContraIndications do
  include_context 'with stubbed env'

  describe ".poke_contraindicated? additional branches" do
    before do
      # Ensure global silenced is false for these tests
      FlossFunding.silenced = false
    end

    it "returns true when CI env var is 'true' (case-insensitive)" do
      stub_env("CI" => "TrUe")
      expect(described_class.poke_contraindicated?).to be(true)
    end

    it "returns true when Dir.pwd raises StandardError" do
      allow(Dir).to receive(:pwd).and_raise(StandardError)
      expect(described_class.poke_contraindicated?).to be(true)
    end
  end

  describe ".at_exit_contraindicated? additional branches" do
    it "returns true when Constants::SILENT is true" do
      stub_const("FlossFunding::Constants::SILENT", true)
      allow(FlossFunding).to receive(:silenced).and_return(false)
      allow(FlossFunding).to receive(:configurations).and_return({})
      expect(described_class.at_exit_contraindicated?).to be(true)
    end

    it "handles non-hash non-to_h config entries via else branch as non-silencing" do
      cfg = {
        "Lib::Three" => 123,
      }
      allow(FlossFunding).to receive(:silenced).and_return(false)
      allow(FlossFunding).to receive(:configurations).and_return(cfg)
      expect(described_class.at_exit_contraindicated?).to be(false)
    end
  end
end
