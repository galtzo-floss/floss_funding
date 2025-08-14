# frozen_string_literal: true

RSpec.describe FlossFunding::Namespace do
  include_context "with stubbed env"

  describe "#initialize state derivation" do
    before do
      # Ensure global calls do not output
      allow(FlossFunding).to receive(:start_coughing)
      allow(FlossFunding).to receive(:start_begging)
    end

    it "is :unactivated when ENV key is missing/empty" do
      ns = described_class.new("Alpha")
      expect(ns.state).to eq(FlossFunding::STATES[:unactivated])
    end

    it "is :activated when activation key is unpaid Free-as-in-beer" do
      stub_env(FlossFunding::UnderBar.env_variable_name("Alpha") => FlossFunding::FREE_AS_IN_BEER)
      ns = described_class.new("Alpha")
      expect(ns.state).to eq(FlossFunding::STATES[:activated])
    end

    it "is :activated when activation key is unpaid Business-is-not-good-yet" do
      stub_env(FlossFunding::UnderBar.env_variable_name("Beta") => FlossFunding::BUSINESS_IS_NOT_GOOD_YET)
      ns = described_class.new("Beta")
      expect(ns.state).to eq(FlossFunding::STATES[:activated])
    end

    it "is :activated when activation key is NOT-FINANCIALLY-SUPPORTING-<ns>" do
      envv = FlossFunding::UnderBar.env_variable_name("Gamma")
      stub_env(envv => "#{FlossFunding::NOT_FINANCIALLY_SUPPORTING}-Gamma")
      ns = described_class.new("Gamma")
      expect(ns.state).to eq(FlossFunding::STATES[:activated])
    end

    it "is :invalid when activation key is non-hex garbage" do
      envv = FlossFunding::UnderBar.env_variable_name("Delta")
      stub_env(envv => "not-hex")
      ns = described_class.new("Delta")
      expect(ns.state).to eq(FlossFunding::STATES[:invalid])
    end

    context "with paid 64-hex activation string" do
      let(:envv) { FlossFunding::UnderBar.env_variable_name("Epsilon") }
      let(:hex) { "a" * 64 }

      it "is :activated when decryption yields a valid base word" do
        stub_env(envv => hex)
        allow_any_instance_of(described_class).to receive(:floss_funding_decrypt).and_return("validword")
        allow(FlossFunding).to receive(:check_activation).with("validword").and_return(true)
        ns = described_class.new("Epsilon")
        expect(ns.state).to eq(FlossFunding::STATES[:activated])
      end

      it "falls back to DEFAULT_STATE when base word not valid" do
        stub_env(envv => hex)
        allow_any_instance_of(described_class).to receive(:floss_funding_decrypt).and_return("invalidword")
        allow(FlossFunding).to receive(:check_activation).with("invalidword").and_return(false)
        ns = described_class.new("Epsilon")
        expect(ns.state).to eq(FlossFunding::DEFAULT_STATE)
      end
    end
  end

  describe "#to_s" do
    it "returns the namespace name" do
      expect(described_class.new("Zed").to_s).to eq("Zed")
    end
  end

  describe "#has_state? and #with_state" do
    it "detects presence of events with the given state" do
      lib = instance_double("Lib", :namespace => "Eta")
      ev_a = FlossFunding::ActivationEvent.new(lib, "", :activated)
      ev_u = FlossFunding::ActivationEvent.new(lib, "", :unactivated)
      ns = described_class.new("Eta")
      ns.activation_events = [ev_a, ev_u]
      expect(ns.has_state?(FlossFunding::STATES[:activated])).to be(true)
      expect(ns.with_state(FlossFunding::STATES[:unactivated])).to contain_exactly(ev_u)
    end
  end

  describe "#configs" do
    it "returns library configs from events" do
      cfg = FlossFunding::Configuration.new({"a" => 1})
      lib = instance_double("Lib", :namespace => "Theta", :config => cfg)
      ev = FlossFunding::ActivationEvent.new(lib, "", :unactivated)
      ns = described_class.new("Theta")
      ns.activation_events = [ev]
      expect(ns.configs).to eq([cfg])
    end
  end

  describe "#activation_events= validation" do
    it "accepts only ActivationEvent objects" do
      ns = described_class.new("Iota")
      expect {
        ns.activation_events = [Object.new]
      }.to raise_error(FlossFunding::Error, /activation_events must be an array/)
    end
  end

  describe "#check_unpaid_silence variants" do
    let(:ns) { described_class.new("Kappa") }

    it "returns false for empty" do
      expect(ns.check_unpaid_silence("")).to be(false)
    end

    it "returns false for random string" do
      expect(ns.check_unpaid_silence("random")).to be(false)
    end

    it "returns true for unpaid markers" do
      expect(ns.check_unpaid_silence(FlossFunding::FREE_AS_IN_BEER)).to be(true)
      expect(ns.check_unpaid_silence(FlossFunding::BUSINESS_IS_NOT_GOOD_YET)).to be(true)
      expect(ns.check_unpaid_silence("#{FlossFunding::NOT_FINANCIALLY_SUPPORTING}-Kappa")).to be(true)
    end
  end

  describe "#merged_config" do
    it "merges configs via Configuration.merged_config" do
      ns = described_class.new("Lambda")
      cfg1 = FlossFunding::Configuration.new({"a" => 1})
      cfg2 = FlossFunding::Configuration.new({"a" => 2})
      lib1 = instance_double("Lib1", :namespace => "Lambda", :config => cfg1)
      lib2 = instance_double("Lib2", :namespace => "Lambda", :config => cfg2)
      ns.activation_events = [FlossFunding::ActivationEvent.new(lib1, "", :unactivated), FlossFunding::ActivationEvent.new(lib2, "", :unactivated)]
      merged = ns.merged_config
      expect(merged["a"]).to eq([1, 2])
    end
  end
end
