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
      # has been extended with FlossFunding::Fingerprint methods
      expect(TraditionalTest::InnerModule).to respond_to(:floss_funding_fingerprint)
    end

    it "sets up the correct environment variable name based on the module's name", :check_output do
      configure_contraindications!(:at_exit => {:stdout_tty => true})
      expect do
        # Re-include to trigger output by stubbing the module again
        stub_const("TraditionalTest::InnerModule", Module.new)
        TraditionalTest::InnerModule.send(:include, described_class.new(__FILE__))
      end.to output(/TRADITIONAL_TEST_INNER_MODULE/).to_stdout
    end
  end

  describe "custom namespace usage pattern" do
    before do
      # Stub the module to ensure it's clean for each test
      stub_const("CustomTest::InnerModule", Module.new)
      # Include the Poke module with custom namespace
      CustomTest::InnerModule.send(:include, described_class.new(__FILE__, :namespace => "MyNamespace::V4"))
    end

    it "uses the provided namespace" do
      # We can't directly test the namespace used, but we can check that the module
      # has been extended with FlossFunding::Fingerprint methods
      expect(CustomTest::InnerModule).to respond_to(:floss_funding_fingerprint)
    end

    it "sets up the correct environment variable name based on the provided namespace", :check_output do
      configure_contraindications!(:at_exit => {:stdout_tty => true})
      expect do
        # Re-include to trigger output by stubbing the module again
        stub_const("CustomTest::InnerModule", Module.new)
        CustomTest::InnerModule.send(:include, described_class.new(__FILE__, :namespace => "MyNamespace::V4"))
      end.to output(/MY_NAMESPACE_V4/).to_stdout
    end
  end

  describe ".new" do
    it "returns a module" do
      expect(described_class.new(__FILE__)).to be_a(Module)
    end

    it "accepts a namespace parameter" do
      # This test just verifies that the method accepts parameters
      # The actual functionality is tested in the custom namespace tests
      expect { described_class.new(__FILE__, :namespace => "Test") }.not_to raise_error
    end
  end
end

RSpec.describe FlossFunding::Poke do
  describe ".included (error path)" do
    it "raises if FlossFunding::Poke is included directly" do
      expect do
        module DirectIncludeTest
          include FlossFunding::Poke
        end
      end.to raise_error(FlossFunding::Error, /Do not include FlossFunding::Poke directly/)
    end
  end
end

RSpec.describe FlossFunding::Poke do
  describe ".new (global SILENT path)" do
    it "returns an inert module when :silent => true is provided and does not set up begging" do
      test_mod = Module.new

      output = capture(:stdout) do
        test_mod.send(:include, described_class.new(__FILE__, :silent => true))
      end

      # Should be truly silent and not extend Check methods
      expect(output).to eq("")
      # And global silenced flag should be set
      expect(FlossFunding.silenced).to be(true)
    end
  end
end
