# frozen_string_literal: true

RSpec.describe FlossFunding::Poke do
  let(:including_path) { __FILE__ }

  it "when :wedge => true only injects Fingerprint and does not raise" do
    mod = Module.new
    mod.send(:include, described_class.new(including_path, :wedge => true))
    expect(mod).to respond_to(:floss_funding_fingerprint)
  end

  context "when :wedge is falsy" do
    it "raises if specified config_file does not exist at library root" do
      stub_const("WedgeTest1", Module.new)
      expect {
        WedgeTest1.send(:include, described_class.new(including_path, :config_file => ".missing.yml"))
      }.to raise_error(FlossFunding::Error, "Missing library root path due to: Missing required config file: " \
        "\".missing.yml\"; run `bundle exec rake floss_funding:install` to create one.")
    end

    it "raises if required keys are missing" do
      Dir.mktmpdir do |tmp|
        cfg_path = File.join(tmp, ".floss_funding.yml")
        File.write(cfg_path, {"library_name" => "my_lib"}.to_yaml) # missing funding_uri
        # Use an including_path within tmp so root discovery finds tmp as the root
        including = File.join(tmp, "lib", "x.rb")
        FileUtils.mkdir_p(File.dirname(including))
        File.write(including, "# stub")
        stub_const("WedgeTest2", Module.new)
        expect {
          WedgeTest2.send(:include, described_class.new(including, :config_file => ".floss_funding.yml"))
        }.to raise_error(FlossFunding::Error, /missing required keys: funding_uri/)
      end
    end

    it "allows inclusion when required keys are present" do
      Dir.mktmpdir do |tmp|
        cfg_path = File.join(tmp, ".floss_funding.yml")
        File.write(cfg_path, {"library_name" => "my_lib", "funding_uri" => "https://fund.example"}.to_yaml)
        including = File.join(tmp, "lib", "x.rb")
        FileUtils.mkdir_p(File.dirname(including))
        File.write(including, "# stub")
        stub_const("WedgeNamedMod", Module.new)
        expect {
          WedgeNamedMod.send(:include, described_class.new(including, :config_file => ".floss_funding.yml"))
        }.not_to raise_error
      end
    end
  end
end
