# frozen_string_literal: true

RSpec.describe FlossFunding do
  include(ActivationEventsHelper)

  describe "time helpers and activation checking" do
    before do
      described_class.instance_variable_set(:@loaded_at, Time.utc(2025, 8, 1, 0, 0, 0))
    end

    after do
      described_class.instance_variable_set(:@loaded_at, nil)
    end

    it "returns deterministic loaded_at and computes loaded_month" do
      expect(described_class.loaded_at).to eq(Time.utc(2025, 8, 1, 0, 0, 0))
      expect(described_class.loaded_month).to be_a(Integer)
    end

    it "falls back to precomputed @loaded_month when loaded_at is nil" do
      described_class.instance_variable_set(:@loaded_at, nil)
      expect(described_class.loaded_month).to eq(described_class.instance_variable_get(:@loaded_month))
    end

    it "computes num_valid_words_for_month as difference from START_MONTH" do
      expect(described_class.instance_variable_get(:@num_valid_words_for_month)).to eq(described_class.loaded_month - FlossFunding::START_MONTH)
    end

    it "check_activation returns true when base word is in the current set" do
      # Force n to a positive value and control base_words set
      described_class.instance_variable_set(:@num_valid_words_for_month, 3)
      allow(described_class).to receive(:base_words).with(3).and_return(%w[alpha beta gamma])
      expect(described_class.check_activation("beta")).to be(true)
    end
  end

  describe "start_begging variants", :check_output do
    it "returns early with no output when contraindicated" do
      allow(FlossFunding::ContraIndications).to receive(:at_exit_contraindicated?).and_return(true)
      expect {
        described_class.start_begging("Ns", "ENVV", "mygem")
      }.not_to output.to_stdout
    end

    it "prints a message when not contraindicated" do
      allow(FlossFunding::ContraIndications).to receive(:at_exit_contraindicated?).and_return(false)
      expect {
        described_class.start_begging("Ns", "ENVV", "mygem")
      }.to output(/FLOSS Funding: Activation key missing for mygem/).to_stdout
    end
  end

  describe "initiate_begging branches" do
    it "does nothing when state is activated" do
      ev = make_event("Ns", :activated, :library_name => "g")
      expect(FlossFunding).not_to receive(:start_begging)
      expect(FlossFunding).not_to receive(:start_coughing)
      described_class.initiate_begging(ev)
    end

    it "begs when state is unactivated" do
      ev = make_event("Ns2", :unactivated, :library_name => "g2")
      # Ensure lockfile sentinel does not gate this unit test
      allow(FlossFunding::Lockfile).to receive(:on_load).and_return(nil)
      expect(FlossFunding).to receive(:start_begging)
      described_class.initiate_begging(ev)
    end
  end

  describe "namespaces and silenced accessors" do
    before do
      described_class.namespaces = {}
    end

    it "namespaces getter returns a dup that does not affect internal state when mutated" do
      ns = FlossFunding::Namespace.new("DupNS")
      ev = make_event("DupNS", :unactivated)
      described_class.add_or_update_namespace_with_event(ns, ev)
      snapshot = described_class.namespaces
      snapshot["HACK"] = ns
      expect(described_class.namespaces.key?("HACK")).to be(false)
    end

    it "silenced boolean toggles via accessor" do
      old = described_class.silenced
      described_class.silenced = !old
      expect(described_class.silenced).to eq(!old)
      # restore
      described_class.silenced = old
    end
  end
end
