# frozen_string_literal: true

RSpec.describe FlossFunding::FileFinder do
  describe "#find_file_upwards" do
    it "returns nil when the matching path is a directory (e.g., spec/fixtures)" do
      # Build a simple object that includes the FileFinder instance methods
      helper = Class.new { include FlossFunding::FileFinder }.new

      # Determine repo root relative to this spec file to avoid Dir.pwd assumptions
      # The repo root needs to be below the directory we are looking for,
      # since find_file_upwards ascends.
      repo_root = File.expand_path("../../spec_fixtures/gem_mine", __dir__)

      # 'spec/fixtures' exists in the repo, but it is a directory, not a file
      result = helper.find_file_upwards("spec/fixtures", repo_root)

      expect(result).to be_nil
    end

    it "returns file when the matching path is an existing file (e.g., spec/fixtures/.floss_funding.yml)" do
      # Build a simple object that includes the FileFinder instance methods
      helper = Class.new { include FlossFunding::FileFinder }.new

      # Determine repo root relative to this spec file to avoid Dir.pwd assumptions
      # The repo root needs to be below the directory we are looking for,
      # since find_file_upwards ascends.
      repo_root = File.expand_path("../../spec_fixtures/gem_mine", __dir__)

      # 'spec/fixtures' exists in the repo, but it is a directory, not a file
      result = helper.find_file_upwards("spec/fixtures/.floss_funding.yml", repo_root)

      expect(result).to match("spec/fixtures/.floss_funding.ym")
    end

    it "raises TypeError when start_dir is nil" do
      helper = Class.new { include FlossFunding::FileFinder }.new
      expect { helper.find_file_upwards("some.file", nil) }.to raise_error(TypeError)
    end

    it "raises TypeError when filename is nil" do
      helper = Class.new { include FlossFunding::FileFinder }.new
      repo_root = File.expand_path("../../spec_fixtures/gem_mine", __dir__)
      expect { helper.find_file_upwards(nil, repo_root) }.to raise_error(TypeError)
    end
  end

  describe "#find_last_file_upwards" do
    it "raises TypeError when start_dir is nil" do
      helper = Class.new { include FlossFunding::FileFinder }.new
      expect { helper.find_last_file_upwards("some.file", nil) }.to raise_error(TypeError)
    end

    it "raises TypeError when filename is nil" do
      helper = Class.new { include FlossFunding::FileFinder }.new
      repo_root = File.expand_path("../../spec_fixtures/gem_mine", __dir__)
      expect { helper.find_last_file_upwards(nil, repo_root) }.to raise_error(TypeError)
    end
  end
end
