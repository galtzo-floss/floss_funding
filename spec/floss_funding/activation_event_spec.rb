# frozen_string_literal: true

RSpec.describe FlossFunding::ActivationEvent do
  describe "#initialize and state normalization" do
    let(:lib) { instance_double("Lib", :namespace => "Ns") }

    before do
      # Deterministic time source
      FlossFunding.now_time = Time.utc(2025, 1, 1, 0, 0, 0)
    end

    after do
      FlossFunding.now_time = nil
    end

    it "stores attributes and uses FlossFunding.now_time" do
      ev = described_class.new(lib, "", :unactivated, :silent_flag)
      expect(ev.library).to eq(lib)
      expect(ev.activation_key).to eq("")
      expect(ev.state).to eq(FlossFunding::STATES[:unactivated])
      expect(ev.silent).to eq(:silent_flag)
      expect(ev.send(:occurred_at)).to eq(Time.utc(2025, 1, 1, 0, 0, 0))
    end

    it "accepts string state names that are valid" do
      ev = described_class.new(lib, "", "activated")
      expect(ev.state).to eq(FlossFunding::STATES[:activated])
    end

    it "coerces symbol states via key mapping" do
      ev = described_class.new(lib, "", :activated)
      expect(ev.state).to eq(FlossFunding::STATES[:activated])
    end

    it "falls back to DEFAULT_STATE for invalid key" do
      ev = described_class.new(lib, "", :bogus)
      expect(ev.state).to eq(FlossFunding::DEFAULT_STATE)
    end

    it "falls back to DEFAULT_STATE for invalid value" do
      ev = described_class.new(lib, "", "bogus")
      expect(ev.state).to eq(FlossFunding::DEFAULT_STATE)
    end

    it "falls back to DEFAULT_STATE when state is nil" do
      ev = described_class.new(lib, "", nil)
      expect(ev.state).to eq(FlossFunding::DEFAULT_STATE)
    end
  end
end
