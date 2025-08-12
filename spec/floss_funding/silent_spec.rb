# frozen_string_literal: true

require "spec_helper"

RSpec.describe "FlossFunding::Silent integration" do
  context "when loading the silent helper" do
    it "does not emit any output (silenced)", :check_output do
      # Ensure the constant is not already loaded from a previous run
      if Object.const_defined?(:FlossFunding) && FlossFunding.const_defined?(:Silent)
        FlossFunding.send(:remove_const, :Silent)
      end

      output = capture(:stdout) do
        require "floss_funding/silent"
      end

      expect(output).to eq("")
    end

    it "registers a silent=true preference in configuration" do
      # Load once if not already loaded
      require "floss_funding/silent" unless Object.const_defined?(:FlossFunding) && FlossFunding.const_defined?(:Silent)

      config = FlossFunding.configuration("FlossFunding::Silent")
      # It should exist and include a truthy silent flag we passed via Poke.new
      expect(config).to be_a(FlossFunding::Configuration)
      expect(Array(config["silent"]).any?).to be(true)
      expect(Array(config["silent"]).first).to be(true)
    end
  end
end
