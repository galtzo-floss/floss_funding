# frozen_string_literal: true

RSpec.describe FlossFunding::Library do
  describe "::reset_caches!" do
    it "clears yaml_config_cache and gemspec_name_cache" do
      Dir.mktmpdir do |tmp|
        # Prepare a YAML file to populate yaml_config_cache
        yaml_path = File.join(tmp, ".floss_funding.yml")
        File.write(yaml_path, { "funding_donation_uri" => "https://example.test/donate" }.to_yaml)

        # Populate yaml cache
        abs_yaml = File.expand_path(yaml_path)
        data = described_class.load_yaml_config(abs_yaml)
        expect(data).to be_a(Hash)
        expect(described_class.yaml_config_cache).to have_key(abs_yaml)

        # Prepare a gemspec to populate gemspec_name_cache
        gemspec_path = File.join(tmp, "demo.gemspec")
        File.write(gemspec_path, "name = 'demo_reset_cache'")

        name = described_class.gem_name_for(gemspec_path)
        expect(name).to eq("demo_reset_cache")
        abs_gemspec = File.expand_path(gemspec_path)
        expect(described_class.gemspec_name_cache).to have_key(abs_gemspec)

        # Now reset caches
        described_class.reset_caches!

        expect(described_class.yaml_config_cache).to eq({})
        expect(described_class.gemspec_name_cache).to eq({})
      end
    end

    it "allows caches to repopulate after reset" do
      Dir.mktmpdir do |tmp|
        described_class.reset_caches!

        yaml_path = File.join(tmp, ".floss_funding.yml")
        File.write(yaml_path, { "funding_subscription_uri" => "https://example.test/subscribe" }.to_yaml)

        _ = described_class.load_yaml_config(yaml_path)
        expect(described_class.yaml_config_cache).to have_key(File.expand_path(yaml_path))

        gemspec_path = File.join(tmp, "after_reset.gemspec")
        File.write(gemspec_path, "name = 'after_reset'")

        _ = described_class.gem_name_for(gemspec_path)
        expect(described_class.gemspec_name_cache).to have_key(File.expand_path(gemspec_path))
      end
    end
  end
end
