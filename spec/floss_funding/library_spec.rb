# frozen_string_literal: true

require "securerandom"

RSpec.describe FlossFunding::Library do
  before do
    described_class.reset_caches!
  end

  let(:including_path) { __FILE__ }
  let(:namespace) { FlossFunding::Namespace.new("TestModule") }

  describe "::parse_gemspec_name" do
    it "returns nil for constant-assigned name and matches for literal-assigned name" do
      Dir.mktmpdir do |tmp|
        # Case 1: name does not match regex (uses constant)
        const_dir = File.join(tmp, "const_gem")
        result = GemMine::Generator.new(
          :root_dir => const_dir,
          :count => 1,
          :group_size => 1,
          :gem_name_prefix => "const_gem_",
          :gemspec_extras => {:name_literal => "GEM_NAME"},
          :overwrite => true,
          :cleanup => true,
        ).run
        gemspec1 = result[:gems].first[:gemspec_path]
        File.open(gemspec1, "a") { |f| f << "\nGEM_NAME = 'constant_name'\n" }
        expect(described_class.parse_gemspec_name(gemspec1)).to be_nil

        # Case 2: generate a default gem via GemMine, then normalize line to 'name = ...' to satisfy regex
        lit_dir = File.join(tmp, "literal_gem")
        result2 = GemMine::Generator.new(
          :root_dir => lit_dir,
          :count => 1,
          :group_size => 1,
          :gem_name_prefix => "literal_gem_",
          :overwrite => true,
          :cleanup => true,
        ).run
        gemspec2 = result2[:gems].first[:gemspec_path]
        expected_name = result2[:gems].first[:gem_name]
        content = File.read(gemspec2)
        File.write(gemspec2, content.sub(/s\.name\s*=\s*(["'])([^"']+)\1/, "name = '#{expected_name}'"))
        expect(described_class.parse_gemspec_name(gemspec2)).to eq(expected_name)
      end
    end
  end

  describe "::gem_name_for" do
    it "uses lightweight parse when possible and does not load Gem::Specification" do
      Dir.mktmpdir do |tmp|
        dir = File.join(tmp, "light_parse")
        result = GemMine::Generator.new(
          :root_dir => dir,
          :count => 1,
          :group_size => 1,
          :gem_name_prefix => "light_parse_",
          :overwrite => true,
          :cleanup => true,
        ).run
        gemspec = result[:gems].first[:gemspec_path]
        expected = result[:gems].first[:gem_name]
        # Ensure the gemspec has a direct name assignment that our regex can read quickly
        content = File.read(gemspec)
        File.write(gemspec, content.sub(/s\.name\s*=\s*(["'])([^"']+)\1/, "name = '#{expected}'"))

        allow(Gem::Specification).to receive(:load).and_raise("should not be called")

        got = described_class.gem_name_for(gemspec)
        expect(got).to eq(expected)
      end
    end

    it "falls back to Gem::Specification.load when parse returns nil" do
      Dir.mktmpdir do |tmp|
        dir = File.join(tmp, "const_name")
        result = GemMine::Generator.new(
          :root_dir => dir,
          :count => 1,
          :group_size => 1,
          :gem_name_prefix => "const_name_",
          :gemspec_extras => {:name_literal => "GEM_NAME"},
          :overwrite => true,
          :cleanup => true,
        ).run
        gemspec = result[:gems].first[:gemspec_path]
        const_val = "constant_name_#{SecureRandom.hex(2)}"
        content = File.read(gemspec)
        File.write(gemspec, "GEM_NAME = '#{const_val}'\n" + content)

        # Sanity: lightweight parse should not find a direct literal
        expect(described_class.parse_gemspec_name(gemspec)).to be_nil

        # Now gem_name_for should load the gemspec to evaluate the constant
        got = described_class.gem_name_for(gemspec)
        expect(got).to eq(const_val)
      end
    end

    it "returns nil and does not cache when gemspec cannot be parsed or loaded" do
      Dir.mktmpdir do |tmp|
        gemspec = File.join(tmp, "broken.gemspec")
        File.write(gemspec, "this is not valid ruby")

        allow(Gem::Specification).to receive(:load).and_return(nil)

        got = described_class.gem_name_for(gemspec)
        expect(got).to be_nil

        abs = File.expand_path(gemspec)
        cache = described_class.gemspec_name_cache
        expect(cache).not_to have_key(abs)
      end
    end

    it "caches successful lookups keyed by absolute path" do
      Dir.mktmpdir do |tmp|
        dir = File.join(tmp, "cache_demo")
        result = GemMine::Generator.new(
          :root_dir => dir,
          :count => 1,
          :group_size => 1,
          :gem_name_prefix => "cache_demo_",
          :overwrite => true,
          :cleanup => true,
        ).run
        gemspec = result[:gems].first[:gemspec_path]
        expected = result[:gems].first[:gem_name]
        content = File.read(gemspec)
        File.write(gemspec, content.sub(/s\.name\s*=\s*(["'])([^"']+)\1/, "name = '#{expected}'"))

        first = described_class.gem_name_for(gemspec)
        expect(first).to eq(expected)

        # Change the file to a different name to ensure cache is used
        File.write(gemspec, content.sub(/s\.name\s*=\s*(["'])([^"']+)\1/, "name = 'different'"))
        allow(Gem::Specification).to receive(:load).and_raise("should use cache")

        second = described_class.gem_name_for(gemspec)
        expect(second).to eq(expected)
      end
    end
  end

  describe "#load_config via YAML + defaults" do
    it "loads the configuration from the file and normalizes to arrays" do
      fixture = File.join(File.dirname(__FILE__), "../fixtures/.floss_funding.yml")
      allow(FlossFunding::ConfigFinder).to receive(:find_config_path).and_return(fixture)

      lib = described_class.new(namespace, nil, "TestModule", including_path, namespace.env_var_name)

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

      lib = described_class.new(namespace, nil, "TestModule", including_path, namespace.env_var_name)

      defaults = FlossFunding::ConfigLoader.default_configuration
      expect(lib.config["suggested_donation_amounts"]).to eq(Array(defaults["suggested_donation_amounts"]))
      expect(lib.config["funding_donation_uri"]).to eq(Array(defaults["funding_donation_uri"]))
      expect(lib.config["funding_subscription_uri"]).to eq(Array(defaults["funding_subscription_uri"]))
    end

    it "merges with default values when default_configuration is augmented" do
      fixture = File.join(File.dirname(__FILE__), "../fixtures/.floss_funding.yml")
      allow(FlossFunding::ConfigFinder).to receive(:find_config_path).and_return(fixture)
      # Augment defaults with a custom key to ensure merge behavior includes it
      orig_default = FlossFunding::ConfigLoader.default_configuration
      allow(FlossFunding::ConfigLoader).to receive(:default_configuration).and_return(orig_default.merge("test_key" => "test_value"))

      lib = described_class.new(namespace, nil, "TestModule", including_path, namespace.env_var_name)

      expect(lib.config.to_h).to include(
        "test_key" => ["test_value"],
        "suggested_donation_amounts" => [10],
        "funding_donation_uri" => ["https://floss-funding.dev/donate"],
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
        "suggested_donation_amounts" => [10],
        "funding_donation_uri" => ["https://floss-funding.dev/donate"],
      )
    end
  end

  describe "::gem_name_for rescue path" do
    it "returns nil when Gem::Specification.load raises" do
      Dir.mktmpdir do |tmp|
        gemspec = File.join(tmp, "raise.gemspec")
        File.write(gemspec, "this is not valid ruby")

        allow(described_class).to receive(:parse_gemspec_name).with(File.expand_path(gemspec)).and_return(nil)
        allow(Gem::Specification).to receive(:load).and_raise(StandardError.new("boom"))

        got = described_class.gem_name_for(gemspec)
        expect(got).to be_nil
      end
    end

    it "does not cache on error" do
      Dir.mktmpdir do |tmp|
        gemspec = File.join(tmp, "raise.gemspec")
        File.write(gemspec, "this is not valid ruby")

        allow(described_class).to receive(:parse_gemspec_name).with(File.expand_path(gemspec)).and_return(nil)
        allow(Gem::Specification).to receive(:load).and_raise(StandardError.new("boom"))

        described_class.gem_name_for(gemspec)

        abs = File.expand_path(gemspec)
        cache = described_class.gemspec_name_cache
        expect(cache).not_to have_key(abs)
      end
    end
  end

  describe "::load_yaml_config rescue path" do
    it "returns an empty hash when YAML.safe_load raises" do
      described_class.reset_caches!
      Dir.mktmpdir do |tmp|
        cfg = File.join(tmp, ".floss_funding.yml")
        File.write(cfg, "key: value")

        allow(YAML).to receive(:safe_load).and_raise(StandardError.new("parse error"))
        result1 = described_class.load_yaml_config(cfg)
        expect(result1).to eq({})
      end
    end

    it "caches the empty result on error" do
      described_class.reset_caches!
      Dir.mktmpdir do |tmp|
        cfg = File.join(tmp, ".floss_funding.yml")
        File.write(cfg, "key: value")
        abs = File.expand_path(cfg)

        allow(YAML).to receive(:safe_load).and_raise(StandardError.new("parse error"))
        described_class.load_yaml_config(cfg)

        cache = described_class.yaml_config_cache
        expect(cache[abs]).to eq({})
      end
    end
  end
end
