# frozen_string_literal: true

RSpec.describe FlossFunding::ConfigFinder do
  describe ".find_config_path" do
    it "returns the DEFAULT_FILE when no project/user config files are found" do
      allow(described_class).to receive(:find_project_dotfile).and_return(nil)
      allow(described_class).to receive(:find_user_dotfile).and_return(nil)
      allow(described_class).to receive(:find_user_xdg_config).and_return(nil)

      path = described_class.find_config_path(Dir.pwd)
      expect(path).to eq(FlossFunding::ConfigFinder::DEFAULT_FILE)
    end
  end

  describe ".project_root" do
    it "returns nil when no root indicator files are found" do
      described_class.instance_variable_set(:@project_root, nil)
      allow(described_class).to receive(:find_last_file_upwards).and_return(nil)
      result = described_class.send(:find_project_root)
      expect(result).to be_nil
    end
  end
end


RSpec.describe FlossFunding::ConfigFinder do
  before do
    described_class.clear_caches!
  end

  describe ".find_project_dotfile and caches (extended)" do
    it "caches lookups and can be cleared" do
      Dir.mktmpdir do |dir|
        # Create a minimal project indicator and dotfile
        File.write(File.join(dir, "Gemfile"), "source 'https://rubygems.org'")
        dot = File.join(dir, ".floss_funding.yml")
        File.write(dot, "---\n")

        # First call populates cache
        path1 = described_class.find_config_path(dir)
        expect(path1).to eq(dot)

        # Second call should be cache hit (exercise branch at key? return)
        path2 = described_class.find_config_path(dir)
        expect(path2).to eq(dot)

        # Clear caches and ensure re-computation occurs
        described_class.clear_caches!
        expect(described_class.find_config_path(dir)).to eq(dot)
      end
    end
  end

  describe ".project_root_for variants" do
    it "returns and caches computed root when indicator present" do
      Dir.mktmpdir do |dir|
        # Create nested directory with a Gemfile inside
        nested = File.join(dir, "a", "b")
        FileUtils.mkdir_p(nested)
        File.write(File.join(nested, "Gemfile"), "# gemfile")

        # First computes
        root1 = described_class.send(:project_root_for, nested)
        expect(root1).to eq(nested)

        # Second hits cache (branch at 57[then])
        root2 = described_class.send(:project_root_for, nested)
        expect(root2).to eq(nested)
      end
    end

    it "returns nil and caches when no indicators are found" do
      Dir.mktmpdir do |dir|
        nested = File.join(dir, "x", "y")
        FileUtils.mkdir_p(nested)
        root1 = described_class.send(:project_root_for, nested)
        expect(root1).to be_nil
        # Second call uses cached nil (branch at 63[then])
        root2 = described_class.send(:project_root_for, nested)
        expect(root2).to be_nil
      end
    end
  end

  describe ".project_root variants" do
    it "returns dirname of last indicator when not the gem's own repo" do
      fake_indicator = File.join(Dir.mktmpdir, "Gemfile")
      FileUtils.mkdir_p(File.dirname(fake_indicator))
      File.write(fake_indicator, "# gemfile")
      allow(described_class).to receive(:find_last_file_upwards).and_return(fake_indicator)
      described_class.clear_caches!
      expect(described_class.project_root).to eq(File.dirname(fake_indicator))
    end
  end

  describe ".find_user_dotfile variants" do
    it "returns nil when HOME is not set" do
      allow(ENV).to receive(:key?).with("HOME").and_return(false)
      expect(described_class.send(:find_user_dotfile)).to be_nil
    end

    it "returns path when dotfile exists in HOME" do
      Dir.mktmpdir do |home|
        dot = File.join(home, ".floss_funding.yml")
        File.write(dot, "---\n")
        allow(ENV).to receive(:key?).with("HOME").and_return(true)
        allow(Dir).to receive(:home).and_return(home)
        expect(described_class.send(:find_user_dotfile)).to eq(dot)
      end
    end
  end

  describe ".find_user_xdg_config variants" do
    it "returns path when XDG config exists" do
      Dir.mktmpdir do |xdg|
        file = File.join(xdg, "rubocop", "config.yml")
        FileUtils.mkdir_p(File.dirname(file))
        File.write(file, "---\n")
        allow(ENV).to receive(:fetch).with("XDG_CONFIG_HOME", "~/.config").and_return(xdg)
        expect(described_class.send(:find_user_xdg_config)).to eq(file)
      end
    end
  end

  describe ".expand_path rescue path" do
    it "returns original path when File.expand_path raises ArgumentError" do
      allow(File).to receive(:expand_path).and_raise(ArgumentError)
      expect(described_class.send(:expand_path, "~/.config")).to eq("~/.config")
    end
  end
end
