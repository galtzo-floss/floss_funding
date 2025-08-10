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
      TraditionalTest::InnerModule.send(:include, described_class.new(__FILE__))
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
        TraditionalTest::InnerModule.send(:include, described_class.new(__FILE__))
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
      CustomTest::InnerModule.send(:include, described_class.new(__FILE__, "MyNamespace::V4"))
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
        CustomTest::InnerModule.send(:include, described_class.new(__FILE__, "MyNamespace::V4"))
      end

      # Check that the output contains the correct env var name
      expect(output).to include("MY_NAMESPACE_V4")
    end
  end

  describe "namespace from config file" do
    before do
      # Ensure a stable module name that differs from the config namespace
      stub_const("ConfigNsTest::InnerModule", Module.new)
      allow(ConfigNsTest::InnerModule).to receive(:name).and_return("ConfigNsTest::InnerModule")

      # Make Config.load_config pick the namespace-enabled fixture
      allow(FlossFunding::Config).to receive(:find_config_file).and_return(
        File.join(File.dirname(__FILE__), "../fixtures/.floss_funding_with_namespace.yml"),
      )
    end

    it "uses the namespace specified in .floss_funding.yml when no custom namespace is provided" do
      output = capture(:stdout) do
        ConfigNsTest::InnerModule.send(:include, described_class.new(__FILE__))
      end

      # ENV var should be derived from the config namespace "Config::Namespace"
      expect(output).to include("CONFIG_NAMESPACE")
      # And should not be derived from the module name
      expect(output).not_to include("CONFIG_NS_TEST_INNER_MODULE")
    end
  end

  describe ".new" do
    it "returns a module" do
      expect(described_class.new(__FILE__)).to be_a(Module)
    end

    it "accepts a namespace parameter" do
      # This test just verifies that the method accepts parameters
      # The actual functionality is tested in the custom namespace tests
      expect { described_class.new(__FILE__, "Test") }.not_to raise_error
    end
  end
end
