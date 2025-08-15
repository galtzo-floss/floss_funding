# frozen_string_literal: true

require "floss_funding/rakelib/gem_spec_reader"

RSpec.describe FlossFunding::Rakelib::GemSpecReader do
  describe "::read" do
    ["symbols", "strings"].each do |type|
      context "when gemspec has #{type}-keyed metadata", :check_output do
        let(:library_root) { "spec/fixtures/gemspecs/#{type}" }

        it "returns a hash" do
          result = described_class.read(library_root)
          expect(result).to be_a(Hash)
        end

        it "has funding_uri", :check_output do
          result = described_class.read(library_root)
          expect(result[:funding_uri]).to eq("https://github.com/sponsors/pboling")
        end
      end
    end
  end

  describe "rescue and branch paths for read_gemspec_data" do
    it "returns {} when gemspec is found but Gem::Specification.load returns nil" do
      allow(Dir).to receive(:glob).and_return(["/tmp/fake.gemspec"]) # ensure path discovered
      allow(Gem::Specification).to receive(:load).and_return(nil)
      result = described_class.read("/tmp")
      expect(result).to eq({})
    end

    it "returns {} when Gem::Specification.load raises (rescued)" do
      allow(Dir).to receive(:glob).and_return(["/tmp/fake.gemspec"]) # ensure path discovered
      allow(Gem::Specification).to receive(:load).and_raise(StandardError)
      result = silence_stderr do
        described_class.read("/tmp")
      end
      expect(result).to eq({})
    end

    it "returns {} when Gem::Specification.load raises (rescued)", :check_output do
      allow(Dir).to receive(:glob).and_return(["/tmp/fake.gemspec"]) # ensure path discovered
      allow(Gem::Specification).to receive(:load).and_raise(StandardError)
      output = capture(:stderr) do
        described_class.read("/tmp")
      end
      expect(output).to include(
        "[floss_funding] Error reading gemspec in /tmp:",
        "StandardError",
      )
    end

    it "extracts fields and supports funding_uri from metadata symbol key" do
      fake_spec = Struct.new(:name, :homepage, :authors, :email, :metadata).new(
        "gemy", "https://example.test", ["Ada"], ["ada@example.test"], {:funding_uri => "https://fund.me"}
      )
      allow(Dir).to receive(:glob).and_return(["/tmp/fake.gemspec"]) # ensure path discovered
      allow(Gem::Specification).to receive(:load).and_return(fake_spec)

      result = described_class.read("/tmp")
      expect(result).to eq(
        :library_name => "gemy",
        :homepage => "https://example.test",
        :authors => ["Ada"],
        :email => ["ada@example.test"],
        :funding_uri => "https://fund.me",
      )
    end

    it "extracts fields and supports funding_uri from metadata string key" do
      fake_spec = Struct.new(:name, :homepage, :authors, :email, :metadata).new(
        "gemz", "https://example.org", ["Linus"], ["linus@example.org"], {"funding_uri" => "https://fund.str"}
      )
      allow(Dir).to receive(:glob).and_return(["/tmp/fake2.gemspec"]) # ensure path discovered
      allow(Gem::Specification).to receive(:load).and_return(fake_spec)

      result = described_class.read("/tmp")
      expect(result).to eq(
        :library_name => "gemz",
        :homepage => "https://example.org",
        :authors => ["Linus"],
        :email => ["linus@example.org"],
        :funding_uri => "https://fund.str",
      )
    end
  end
end
