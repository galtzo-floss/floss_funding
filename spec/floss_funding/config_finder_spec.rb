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
