# frozen_string_literal: true

RSpec.describe FlossFunding do
  describe "time helpers and activation checking" do
    before do
      described_class.now_time = Time.utc(2025, 8, 1, 0, 0, 0)
    end

    after do
      described_class.now_time = nil
    end

    it "returns deterministic now_time and computes now_month" do
      expect(described_class.now_time).to eq(Time.utc(2025, 8, 1, 0, 0, 0))
      expect(described_class.now_month).to be_a(Integer)
    end

    it "computes num_valid_words_for_month as difference from START_MONTH" do
      expect(described_class.num_valid_words_for_month).to eq(described_class.now_month - FlossFunding::START_MONTH)
    end

    it "check_activation returns true when base word is in the current set" do
      # Force n to a positive value and control base_words set
      allow(described_class).to receive(:num_valid_words_for_month).and_return(3)
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
      lib = instance_double("Lib", :namespace => "Ns", :gem_name => "g")
      ev = FlossFunding::ActivationEvent.new(lib, "", :activated)
      expect(FlossFunding).not_to receive(:start_begging)
      expect(FlossFunding).not_to receive(:start_coughing)
      described_class.initiate_begging(ev)
    end

    it "begs when state is unactivated" do
      lib = instance_double("Lib", :namespace => "Ns2", :gem_name => "g2")
      ev = FlossFunding::ActivationEvent.new(lib, "", :unactivated)
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
      described_class.add_or_update_namespace_with_event(ns, FlossFunding::ActivationEvent.new(instance_double("Lib", :namespace => "DupNS"), "", :unactivated))
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
