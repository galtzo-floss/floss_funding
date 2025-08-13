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

    it "sets the global silenced flag (no per-library configuration is registered)" do
      # Ensure the constant is not already loaded from a previous example
      if Object.const_defined?(:FlossFunding) && FlossFunding.const_defined?(:Silent)
        FlossFunding.send(:remove_const, :Silent)
      end

      load("floss_funding/silent.rb")

      # Since silencing is global/early, no configuration should be registered for the helper module
      config = FlossFunding.configuration("FlossFunding::Silent")
      expect(config).to be_nil
      expect(FlossFunding.silenced).to be(true)
    end
  end
end
