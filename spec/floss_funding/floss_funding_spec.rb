# frozen_string_literal: true

require "spec_helper"

RSpec.describe FlossFunding do
  describe ".env_var_names (derived)" do
    it "derives env var names from included namespaces and does not expose internals" do
      # Create two modules and include Poke to register namespaces
      stub_const("Alpha", Module.new)
      stub_const("Beta", Module.new)
      Alpha.const_set(:Lib, Module.new)
      Beta.const_set(:Lib, Module.new)
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
      FlossFunding.silenced = ::FlossFunding::Constants::SILENT
      FlossFunding.now_time = nil
    end

    it "covers activation_occurrences false path when a namespace has zero events" do
      ns = FlossFunding::Namespace.new("NoEventsNS", nil, [])
      FlossFunding.namespaces = { ns.name => ns }

      # count == 0 so the modifier-if should not append; SimpleCov records the false branch as the 'else' path
      expect(FlossFunding.activation_occurrences).to eq([])
    end

    it "covers base_words early return for n == 0" do
      # Make current month equal to START_MONTH, resulting in n == 0
      FlossFunding.now_time = Time.new(2025, 7, 1, 0, 0, 0, "+00:00")
      expect(FlossFunding.num_valid_words_for_month).to eq(0)
      expect(FlossFunding.base_words).to eq([])
    end


    it "covers check_activation early return when n <= 0" do
      FlossFunding.now_time = Time.new(2025, 7, 1, 0, 0, 0, "+00:00")
      expect(FlossFunding.num_valid_words_for_month).to eq(0)
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
end
