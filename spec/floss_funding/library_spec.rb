# frozen_string_literal: true

RSpec.describe FlossFunding::Library do
  let(:including_path) { __FILE__ }
  let(:namespace) { FlossFunding::Namespace.new("TestModule") }

  describe "#load_config via YAML + defaults" do
    it "loads the configuration from the file and normalizes to arrays" do
      fixture = File.join(File.dirname(__FILE__), "../fixtures/.floss_funding.yml")
      allow(FlossFunding::ConfigFinder).to receive(:find_config_path).and_return(fixture)

      lib = described_class.new(namespace, "TestModule", including_path)

      expect(lib.config.to_h).to include(
        "suggested_donation_amounts" => [10],
        "funding_donation_uri" => ["https://floss-funding.dev/donate"],
        "funding_subscription_uri" => ["https://floss-funding.dev/subscribe"],
        "gem_name" => ["floss_funding"],
        "silent" => [],
      )
    end

    it "returns defaults when no .floss_funding.yml file exists" do
      allow(FlossFunding::ConfigFinder).to receive(:find_config_path).and_return(nil)

      lib = described_class.new(namespace, "TestModule", including_path)

      defaults = FlossFunding::ConfigLoader.default_configuration
      expect(lib.config["suggested_donation_amount"]).to eq([defaults["suggested_donation_amount"]])
      expect(lib.config["floss_funding_url"]).to eq([defaults["floss_funding_url"]])
    end

    it "merges with default values when default_configuration is augmented" do
      fixture = File.join(File.dirname(__FILE__), "../fixtures/.floss_funding.yml")
      allow(FlossFunding::ConfigFinder).to receive(:find_config_path).and_return(fixture)
      # Augment defaults with a custom key to ensure merge behavior includes it
      orig_default = FlossFunding::ConfigLoader.default_configuration
      allow(FlossFunding::ConfigLoader).to receive(:default_configuration).and_return(orig_default.merge("test_key" => "test_value"))

      lib = described_class.new(namespace, "TestModule", including_path)

      expect(lib.config.to_h).to include(
        "test_key" => ["test_value"],
        "suggested_donation_amount" => [10],
        "floss_funding_url" => ["https://example.com/fund"],
      )
    end
  end

  describe "integration with Poke" do
    it "loads and stores configuration when Poke is included" do
      fixture = File.join(File.dirname(__FILE__), "../fixtures/.floss_funding.yml")
      allow(FlossFunding::ConfigFinder).to receive(:find_config_path).and_return(fixture)
      allow_any_instance_of(Module).to receive(:floss_funding_initiate_begging)

      test_module = Module.new
      allow(test_module).to receive(:name).and_return("TestModule")

      test_module.include(FlossFunding::Poke.new(__FILE__))

      config = FlossFunding.configurations("TestModule")
      expect(config.to_h).to include(
        "suggested_donation_amount" => [10],
        "floss_funding_url" => ["https://example.com/fund"],
      )
    end
  end
end
