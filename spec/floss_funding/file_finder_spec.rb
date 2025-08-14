# frozen_string_literal: true

RSpec.describe FlossFunding::FileFinder do
  describe "#find_file_upwards" do
    it "returns nil when the matching path is a directory (e.g., spec/fixtures)" do
      # Build a simple object that includes the FileFinder instance methods
      helper = Class.new { include FlossFunding::FileFinder }.new

      # Determine repo root relative to this spec file to avoid Dir.pwd assumptions
      repo_root = File.expand_path("../..", __dir__)

      # 'spec/fixtures' exists in the repo, but it is a directory, not a file
      result = helper.find_file_upwards("spec/fixtures", repo_root)

      expect(result).to be_nil
    end
  end
end
