# frozen_string_literal: true

RSpec.describe FlossFunding::Poke do
  let(:including_path) { __FILE__ }

  it "when :wedge => true only injects Fingerprint and does not raise" do
    mod = Module.new
    mod.send(:include, described_class.new(including_path, :wedge => true))
    expect(mod).to respond_to(:floss_funding_fingerprint)
  end

  context "when :wedge is falsy" do
    it "raises if no .floss_funding.yml exists" do
      allow(FlossFunding::ConfigFinder).to receive(:find_config_path).and_return(nil)
      mod = Module.new
      expect {
        mod.send(:include, described_class.new(including_path))
      }.to raise_error(FlossFunding::Error, /Missing required .floss_funding.yml/)
    end

    it "raises if required keys are missing" do
      Dir.mktmpdir do |tmp|
        cfg_path = File.join(tmp, ".floss_funding.yml")
        File.write(cfg_path, {"library_name" => "my_lib"}.to_yaml) # missing funding_uri
        allow(FlossFunding::ConfigFinder).to receive(:find_config_path).and_return(cfg_path)
        mod = Module.new
        expect {
          mod.send(:include, described_class.new(including_path))
        }.to raise_error(FlossFunding::Error, /missing required keys: funding_uri/)
      end
    end

    it "allows inclusion when required keys are present" do
      Dir.mktmpdir do |tmp|
        cfg_path = File.join(tmp, ".floss_funding.yml")
        File.write(cfg_path, {"library_name" => "my_lib", "funding_uri" => "https://fund.example"}.to_yaml)
        allow(FlossFunding::ConfigFinder).to receive(:find_config_path).and_return(cfg_path)
        stub_const("WedgeNamedMod", Module.new)
        expect {
          WedgeNamedMod.send(:include, described_class.new(including_path))
        }.not_to raise_error
      end
    end
  end
end
