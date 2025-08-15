# frozen_string_literal: true

require "spec_helper"

RSpec.describe FlossFunding do
  include(ActivationEventsHelper)

  describe "namespace queries and file-based behaviors" do
    before do
      FlossFunding.namespaces = {}
    end

    it "all_namespaces behaves as expected" do
      ns1 = FlossFunding::Namespace.new("Ns1")
      ns2 = FlossFunding::Namespace.new("Ns2")

      ev1 = make_event(ns1.name, :activated, :library_name => "g1", :class_name => "Lib1")
      ev2 = make_event(ns1.name, :unactivated, :library_name => "g1", :class_name => "Lib1")
      ev3 = make_event(ns2.name, :invalid, :library_name => "g2", :class_name => "Lib2")

      ns1.activation_events = [ev1, ev2]
      ns2.activation_events = [ev3]

      FlossFunding.add_or_update_namespace_with_event(ns1, ev1)
      FlossFunding.add_or_update_namespace_with_event(ns2, ev3)

      expect(FlossFunding.all_namespaces.map(&:name).sort).to eq(["Ns1", "Ns2"])
      expect(FlossFunding.all_namespaces.sort_by(&:name).map(&:state)).to eq(["unactivated", "unactivated"])
    end

    it "initiate_begging calls start_coughing when event is invalid" do
      event = make_event("NsZ", :invalid, :key => "deadbeef", :library_name => "gemz", :class_name => "Lib")

      expect(FlossFunding).to receive(:start_coughing).with(
        "deadbeef",
        "NsZ",
        FlossFunding::UnderBar.env_variable_name("NsZ"),
      )

      FlossFunding.initiate_begging(event)
    end
  end

  describe "branch coverage", :check_output do
    before do
      FlossFunding.namespaces = {}
      FlossFunding.silenced = true
    end

    after do
      FlossFunding.namespaces = {}
      FlossFunding.silenced = FlossFunding::Constants::SILENT
    end

    it "covers base_words early return for n == 0" do
      FlossFunding.instance_variable_set(:@loaded_at, Time.new(2025, 7, 1, 0, 0, 0, "+00:00"))
      FlossFunding.instance_variable_set(:@loaded_month, FlossFunding::START_MONTH)
      FlossFunding.instance_variable_set(:@num_valid_words_for_month, 0)
      expect(FlossFunding.instance_variable_get(:@num_valid_words_for_month)).to eq(0)
      expect(FlossFunding.base_words).to eq([])
    end

    it "covers check_activation early return when n <= 0" do
      FlossFunding.instance_variable_set(:@loaded_at, Time.new(2025, 7, 1, 0, 0, 0, "+00:00"))
      FlossFunding.instance_variable_set(:@loaded_month, FlossFunding::START_MONTH)
      FlossFunding.instance_variable_set(:@num_valid_words_for_month, 0)
      expect(FlossFunding.instance_variable_get(:@num_valid_words_for_month)).to eq(0)
      expect(FlossFunding.check_activation("anything")).to be(false)
    end

    it "covers start_coughing guard return when contraindicated" do
      allow(FlossFunding::ContraIndications).to receive(:at_exit_contraindicated?).and_return(true)
      expect {
        FlossFunding.start_coughing("deadbeef", "NsX", "FLOSS_FUNDING_NSX")
      }.not_to output.to_stdout
    end

    it "covers start_coughing printing path when not contraindicated" do
      allow(FlossFunding::ContraIndications).to receive(:at_exit_contraindicated?).and_return(false)
      expect {
        FlossFunding.start_coughing("deadbeef", "NsY", "FLOSS_FUNDING_NSY")
      }.to output(/COUGH, COUGH\.|Current \(Invalid\) Activation Key: deadbeef/).to_stdout
    end
  end

  describe ".env_var_names (derived)" do
    it "derives env var names from included namespaces and does not expose internals" do
      # Create two modules and include Poke to register namespaces
      stub_const("Alpha", Module.new)
      stub_const("Beta", Module.new)
      Alpha.const_set(:Lib, Module.new)
      Beta.const_set(:Lib, Module.new)
      # Not wedged. env_var_names behavior requires a successful Inclusion.
      # This works here because there is a .floss_funding.yml file at the root of this repo.
      Alpha::Lib.send(:include, FlossFunding::Poke.new(__FILE__))
      Beta::Lib.send(:include, FlossFunding::Poke.new(__FILE__))

      # Derived getter
      expected_alpha = FlossFunding::UnderBar.env_variable_name("Alpha::Lib")
      expected_beta = FlossFunding::UnderBar.env_variable_name("Beta::Lib")

      map = described_class.env_var_names
      expect(map).to include("Alpha::Lib" => expected_alpha, "Beta::Lib" => expected_beta)

      # Mutate the returned copy and ensure a fresh call is unaffected
      map["Alpha::Lib"] = "HACKED"
      fresh = described_class.env_var_names
      expect(fresh["Alpha::Lib"]).to eq(expected_alpha)
    end
  end

  context "with output", :check_output do
    before do
      # Ensure we don't leak state across these examples; spec_helper also snapshots, but we are explicit here
      FlossFunding.namespaces = {}
      FlossFunding.silenced = true
    end

    after do
      FlossFunding.namespaces = {}
      FlossFunding.silenced = FlossFunding::Constants::SILENT
      FlossFunding.instance_variable_set(:@loaded_at, nil)
    end

    it "covers activation_occurrences false path when a namespace has zero events" do
      ns = FlossFunding::Namespace.new("NoEventsNS", nil, [])
      FlossFunding.namespaces = {ns.name => ns}

      # count == 0 so the modifier-if should not append; SimpleCov records the false branch as the 'else' path
      expect(FlossFunding.activation_occurrences).to eq([])
    end

    it "covers base_words early return for n == 0" do
      # Make current month equal to START_MONTH, resulting in n == 0
      FlossFunding.instance_variable_set(:@loaded_at, Time.new(2025, 7, 1, 0, 0, 0, "+00:00"))
      FlossFunding.instance_variable_set(:@loaded_month, FlossFunding::START_MONTH)
      FlossFunding.instance_variable_set(:@num_valid_words_for_month, 0)
      expect(FlossFunding.instance_variable_get(:@num_valid_words_for_month)).to eq(0)
      expect(FlossFunding.base_words).to eq([])
    end

    it "covers check_activation early return when n <= 0" do
      FlossFunding.instance_variable_set(:@loaded_at, Time.new(2025, 7, 1, 0, 0, 0, "+00:00"))
      FlossFunding.instance_variable_set(:@loaded_month, FlossFunding::START_MONTH)
      FlossFunding.instance_variable_set(:@num_valid_words_for_month, 0)
      expect(FlossFunding.instance_variable_get(:@num_valid_words_for_month)).to eq(0)
      expect(FlossFunding.check_activation("anything")).to be(false)
    end

    it "covers start_coughing guard return when contraindicated" do
      # Force ContraIndications to return true so start_coughing returns early (no output)
      allow(FlossFunding::ContraIndications).to receive(:at_exit_contraindicated?).and_return(true)
      expect {
        FlossFunding.start_coughing("deadbeef", "NsX", "FLOSS_FUNDING_NSX")
      }.not_to output.to_stdout
    end

    it "covers start_coughing printing path when not contraindicated" do
      allow(FlossFunding::ContraIndications).to receive(:at_exit_contraindicated?).and_return(false)
      expect {
        FlossFunding.start_coughing("deadbeef", "NsY", "FLOSS_FUNDING_NSY")
      }.to output(/COUGH, COUGH\.|Current \(Invalid\) Activation Key: deadbeef/).to_stdout
    end
  end

  describe "::DEBUG" do
    it "defaults to false when FLOSS_FUNDING_DEBUG is not set" do
      expect(FlossFunding::DEBUG).to be(false)
    end

    it "is true when FLOSS_FUNDING_DEBUG is case-insensitively 'true' at load time" do
      require "open3"
      require "rbconfig"
      ruby = RbConfig.ruby
      lib_dir = File.expand_path("../../lib", __dir__)
      code = 'require "floss_funding"; puts FlossFunding::DEBUG'
      env = {"FLOSS_FUNDING_DEBUG" => "TrUe"}
      stdout, _stderr, _status = Open3.capture3(env, ruby, "-I", lib_dir, "-e", code)
      expect(stdout.strip).to eq("true")
    end

    it "is false when FLOSS_FUNDING_DEBUG is a non-matching value at load time" do
      require "open3"
      require "rbconfig"
      ruby = RbConfig.ruby
      lib_dir = File.expand_path("../../lib", __dir__)
      code = 'require "floss_funding"; puts FlossFunding::DEBUG'
      env = {"FLOSS_FUNDING_DEBUG" => "FALSE"}
      stdout, _stderr, _status = Open3.capture3(env, ruby, "-I", lib_dir, "-e", code)
      expect(stdout.strip).to eq("false")
    end
  end

  describe "::debug_log", :check_output do
    context "when DEBUG is false" do
      before { stub_const("FlossFunding::DEBUG", false) }

      it "returns nil when called with args" do
        expect(described_class.debug_log("hello", "world")).to be_nil
      end

      it "does not output when called with args" do
        expect { described_class.debug_log("hello", "world") }
          .not_to output.to_stdout
      end

      it "does not evaluate the block when called with a block" do
        executed = false
        described_class.debug_log {
          executed = true
          "should not print"
        }
        expect(executed).to be false
      end

      it "does not output when called with a block" do
        expect { described_class.debug_log { "should not print" } }
          .not_to output.to_stdout
      end
    end

    context "when DEBUG is true" do
      before { stub_const("FlossFunding::DEBUG", true) }

      it "returns nil when called with args" do
        expect(described_class.debug_log("hello", :world, 123)).to be_nil
      end

      it "prints joined args separated by spaces" do
        expect { described_class.debug_log("hello", :world, 123) }
          .to output("hello world 123\n").to_stdout
      end

      it "returns nil when called with a block" do
        expect(described_class.debug_log("ignored") { "from block" }).to be_nil
      end

      it "yields to the block and prints its return value" do
        expect { described_class.debug_log("ignored") { "from block" } }
          .to output("from block\n").to_stdout
      end

      it "returns nil even if the block raises" do
        expect(described_class.debug_log { raise "boom" }).to be_nil
      end

      it "does not print when the block raises" do
        expect { described_class.debug_log { raise "boom" } }
          .not_to output.to_stdout
      end
    end
  end
end
