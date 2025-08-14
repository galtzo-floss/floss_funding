# frozen_string_literal: true

require "tmpdir"

RSpec.describe FlossFunding::LibraryRoot do
  describe "::reset_cache! and ::discover recomputation" do
    it "forces discover to recompute results" do
      Dir.mktmpdir do |root|
        nested = File.join(root, "a", "b")
        FileUtils.mkdir_p(nested)
        including_path = File.join(nested, "file.rb")
        File.write(including_path, "# stub")

        # Initially, without any gem indicators, discover returns nil and caches it
        expect(described_class.discover(including_path)).to be_nil

        # Create a Gemfile at the ancestor root and verify cache still returns nil
        File.write(File.join(root, "Gemfile"), "source 'https://rubygems.org'\n")
        expect(described_class.discover(including_path)).to be_nil

        # After cache reset, discover should find the new root
        described_class.reset_cache!
        expect(described_class.discover(including_path)).to eq(root)
      end
    end
  end
end
