# frozen_string_literal: true

# Require the fixture files
require_relative "../fixtures/traditional_test"
require_relative "../fixtures/custom_test"

RSpec.describe FlossFunding::Poke do
  describe "traditional usage pattern" do
    before do
      # Stub the module to ensure it's clean for each test
      stub_const("TraditionalTest::InnerModule", Module.new)
      # Include the Poke module
      TraditionalTest::InnerModule.send(:include, FlossFunding::Poke)
    end

    it "uses the module's name as namespace" do
      # We can't directly test the namespace used, but we can check that the module
      # has been extended with the Check module's methods
      expect(TraditionalTest::InnerModule).to respond_to(:floss_funding_initiate_begging)
    end

    it "sets up the correct environment variable name based on the module's name" do
      output = capture(:stdout) do
        # Re-include to trigger output by stubbing the module again
        stub_const("TraditionalTest::InnerModule", Module.new)
        TraditionalTest::InnerModule.send(:include, FlossFunding::Poke)
      end

      # Check that the output contains the correct env var name
      expect(output).to include("TRADITIONAL_TEST_INNER_MODULE")
    end
  end

  describe "custom namespace usage pattern" do
    before do
      # Stub the module to ensure it's clean for each test
      stub_const("CustomTest::InnerModule", Module.new)
      # Include the Poke module with custom namespace
      CustomTest::InnerModule.send(:include, FlossFunding::Poke.new("MyNamespace::V4"))
    end

    it "uses the provided namespace" do
      # We can't directly test the namespace used, but we can check that the module
      # has been extended with the Check module's methods
      expect(CustomTest::InnerModule).to respond_to(:floss_funding_initiate_begging)
    end

    it "sets up the correct environment variable name based on the provided namespace" do
      output = capture(:stdout) do
        # Re-include to trigger output by stubbing the module again
        stub_const("CustomTest::InnerModule", Module.new)
        CustomTest::InnerModule.send(:include, FlossFunding::Poke.new("MyNamespace::V4"))
      end

      # Check that the output contains the correct env var name
      expect(output).to include("MY_NAMESPACE_V4")
    end
  end

  describe ".new" do
    it "returns a module" do
      expect(described_class.new("Test")).to be_a(Module)
    end

    it "accepts a namespace parameter" do
      # This test just verifies that the method accepts a parameter
      # The actual functionality is tested in the custom namespace tests
      expect { described_class.new("Test") }.not_to raise_error
    end
  end
end
