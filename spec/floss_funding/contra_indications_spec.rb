# frozen_string_literal: true

RSpec.describe FlossFunding::ContraIndications do
  include_context "with stubbed env"

  describe ".poke_contraindicated? additional branches" do
    before do
      # Ensure a clean default contraindication state for these tests
      configure_contraindications!
    end

    it "returns true when CI env var is 'true' (case-insensitive)" do
      configure_contraindications!(poke: { ci: true })
      expect(described_class.poke_contraindicated?).to be(true)
    end

    it "returns true when Dir.pwd raises StandardError" do
      configure_contraindications!(poke: { pwd_raises: true })
      expect(described_class.poke_contraindicated?).to be(true)
    end
  end

  describe ".at_exit_contraindicated? additional branches" do
    it "returns true when Constants::SILENT is true" do
      configure_contraindications!(at_exit: { constants_silent: true, global_silenced: false, configurations: {} })
      expect(described_class.at_exit_contraindicated?).to be(true)
    end

    it "handles non-hash non-to_h config entries via else branch as non-silencing" do
      cfg = {
        "Lib::Three" => 123,
      }
      configure_contraindications!(at_exit: { stdout_tty: true, global_silenced: false, constants_silent: false, configurations: cfg })
      expect(described_class.at_exit_contraindicated?).to be(false)
    end
  end
end
