# frozen_string_literal: true

RSpec.describe FlossFunding::Config do
  describe ".load_config" do
    context "when a .floss_funding.yml file exists" do
      let(:base) { Module.new }

      before do
        # Mock the find_config_file method to return our fixture file
        allow(described_class).to receive(:find_config_file).and_return(
          File.join(File.dirname(__FILE__), "../fixtures/.floss_funding.yml"),
        )
      end

      it "loads the configuration from the file" do
        config = described_class.load_config(__FILE__)

        expect(config).to include(
          "suggested_donation_amount" => 10,
          "floss_funding_url" => "https://example.com/fund",
        )
      end

      it "merges with default values" do
        # Temporarily modify DEFAULT_CONFIG to include a value not in our fixture
        original_default = FlossFunding::Config::DEFAULT_CONFIG.dup
        stub_const("FlossFunding::Config::DEFAULT_CONFIG", original_default.merge("test_key" => "test_value"))

        config = described_class.load_config(__FILE__)

        expect(config).to include("test_key" => "test_value")
        expect(config).to include(
          "suggested_donation_amount" => 10,
          "floss_funding_url" => "https://example.com/fund",
        )
      end
    end

    context "when no .floss_funding.yml file exists" do
      let(:base) { Module.new }

      before do
        allow(described_class).to receive(:find_config_file).and_return(nil)
      end

      it "returns the default configuration" do
        config = described_class.load_config(__FILE__)

        expect(config).to eq(FlossFunding::Config::DEFAULT_CONFIG)
      end
    end
  end

  describe "integration with Poke" do
    let(:test_module) { Module.new }

    before do
      # Mock the find_config_file method to return our fixture file
      allow(FlossFunding::Config).to receive(:find_config_file).and_return(
        File.join(File.dirname(__FILE__), "../fixtures/.floss_funding.yml"),
      )

      # Stub the floss_funding_initiate_begging method to prevent actual output
      allow_any_instance_of(Module).to receive(:floss_funding_initiate_begging)

      # Give the module a name for namespace detection
      allow(test_module).to receive(:name).and_return("TestModule")
    end

    it "loads and stores configuration when included" do
      # Include the Poke module
      test_module.include(FlossFunding::Poke.new(__FILE__))

      # Check that configuration was stored
      config = FlossFunding.configuration("TestModule")

      expect(config).to include(
        "suggested_donation_amount" => 10,
        "floss_funding_url" => "https://example.com/fund",
      )
    end
  end

  describe "key style handling" do
    before do
      allow(described_class).to receive(:find_config_file).and_return("/dev/null")
    end

    it "ignores unknown keys not present in DEFAULT_CONFIG" do
      allow(described_class).to receive(:load_yaml_file).and_return({"unknown_key" => 123})
      config = described_class.load_config(__FILE__)
      expect(config).to eq(FlossFunding::Config::DEFAULT_CONFIG)
    end

    it "does not accept legacy symbol keys (only string keys override)" do
      allow(described_class).to receive(:load_yaml_file).and_return({
        :suggested_donation_amount => 99,
        :floss_funding_url => "https://legacy.example.com",
      })
      config = described_class.load_config(__FILE__)
      # Since only string keys are supported, defaults remain unchanged
      expect(config).to include(
        "suggested_donation_amount" => 5,
        "floss_funding_url" => "https://floss-funding.dev",
      )
    end

    it "allows only known string keys to override defaults" do
      allow(described_class).to receive(:load_yaml_file).and_return({
        "suggested_donation_amount" => 42,
        "floss_funding_url" => "https://ok.example.com",
        "extra" => "ignored",
      })
      config = described_class.load_config(__FILE__)
      expect(config).to include(
        "suggested_donation_amount" => 42,
        "floss_funding_url" => "https://ok.example.com",
      )
      expect(config.key?("extra")).to be false
    end
  end
end
