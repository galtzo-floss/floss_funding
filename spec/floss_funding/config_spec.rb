# frozen_string_literal: true

RSpec.describe FlossFunding::Config do
  describe "rescue and branch paths for read_gemspec_data" do
    it "returns {} when gemspec is found but Gem::Specification.load returns nil" do
      allow(Dir).to receive(:glob).and_return(["/tmp/fake.gemspec"]) # ensure path discovered
      allow(Gem::Specification).to receive(:load).and_return(nil)
      result = described_class.send(:read_gemspec_data, "/tmp")
      expect(result).to eq({})
    end

    it "returns {} when Gem::Specification.load raises (rescued)" do
      allow(Dir).to receive(:glob).and_return(["/tmp/fake.gemspec"]) # ensure path discovered
      allow(Gem::Specification).to receive(:load).and_raise(StandardError)
      result = described_class.send(:read_gemspec_data, "/tmp")
      expect(result).to eq({})
    end

    it "extracts fields and supports funding_uri from metadata symbol key" do
      fake_spec = Struct.new(:name, :homepage, :authors, :metadata).new(
        "gemy", "https://example.test", ["Ada"], {:funding_uri => "https://fund.me"}
      )
      allow(Dir).to receive(:glob).and_return(["/tmp/fake.gemspec"]) # ensure path discovered
      allow(Gem::Specification).to receive(:load).and_return(fake_spec)

      result = described_class.send(:read_gemspec_data, "/tmp")
      expect(result).to eq(
        :name => "gemy",
        :homepage => "https://example.test",
        :authors => ["Ada"],
        :funding_uri => "https://fund.me",
      )
    end
  end

  describe ".find_project_root delegation" do
    it "delegates to ConfigFinder.project_root" do
      allow(FlossFunding::ConfigFinder).to receive(:project_root).and_return("/tmp/proj")
      expect(described_class.find_project_root).to eq("/tmp/proj")
    end
  end

  describe "#normalize_to_array variants" do
    it "returns [] for nil" do
      expect(described_class.send(:normalize_to_array, nil)).to eq([])
    end

    it "returns compacted array for array input" do
      expect(described_class.send(:normalize_to_array, [1, nil, 2])).to eq([1, 2])
    end

    it "wraps scalar in array" do
      expect(described_class.send(:normalize_to_array, 7)).to eq([7])
    end
  end
end

RSpec.describe FlossFunding::ContraIndications do
  describe ".poke_contraindicated? variants" do
    it "returns true when globally silenced" do
      allow(FlossFunding).to receive(:silenced).and_return(true)
      expect(described_class.poke_contraindicated?).to be(true)
    end

    it "returns true when ENV access raises (rescued)" do
      allow(ENV).to receive(:fetch).with("CI", "").and_raise(StandardError)
      allow(STDOUT).to receive(:tty?).and_return(true)
      expect(described_class.poke_contraindicated?).to be(true)
    end

    it "returns true when Dir.pwd raises (rescued)" do
      allow(Dir).to receive(:pwd).and_raise(StandardError)
      allow(STDOUT).to receive(:tty?).and_return(true)
      expect(described_class.poke_contraindicated?).to be(true)
    end

    it "returns true when STDOUT.tty? is false" do
      allow(STDOUT).to receive(:tty?).and_return(false)
      expect(described_class.poke_contraindicated?).to be(true)
    end

    it "returns true when STDOUT.tty? raises (rescued)" do
      allow(STDOUT).to receive(:tty?).and_raise(StandardError)
      expect(described_class.poke_contraindicated?).to be(true)
    end

    it "returns false in a healthy non-CI TTY environment" do
      allow(ENV).to receive(:fetch).with("CI", "").and_return("")
      allow(STDOUT).to receive(:tty?).and_return(true)
      expect(described_class.poke_contraindicated?).to be(false)
    end
  end

  describe ".at_exit_contraindicated? variants" do
    it "returns true when any library provides a truthy callable value" do
      cfg = {
        "Lib::One" => {"silent_callables" => [-> { true }]},
      }
      configure_contraindications!(:at_exit => {:stdout_tty => true, :global_silenced => false, :constants_silent => false})
      allow(FlossFunding).to receive(:configurations).and_return(cfg)
      expect(described_class.at_exit_contraindicated?).to be(true)
    end

    it "returns true when globally silenced" do
      allow(FlossFunding).to receive(:silenced).and_return(true)
      expect(described_class.at_exit_contraindicated?).to be(true)
    end

    it "returns true when STDOUT.tty? is false" do
      allow(STDOUT).to receive(:tty?).and_return(false)
      expect(described_class.at_exit_contraindicated?).to be(true)
    end

    it "returns true when STDOUT.tty? raises (rescued)" do
      allow(STDOUT).to receive(:tty?).and_raise(StandardError)
      expect(described_class.at_exit_contraindicated?).to be(true)
    end

    it "returns false when configs are empty or silent values are non-callable/false" do
      dummy_with_to_h = Struct.new(:h) do
        def to_h
          h
        end
      end
      cfg = {
        "Lib::One" => [dummy_with_to_h.new({"silent_callables" => [-> { false }]}), Object.new],
      }
      configure_contraindications!(:at_exit => {:stdout_tty => true, :global_silenced => false, :constants_silent => false})
      allow(FlossFunding).to receive(:configurations).and_return(cfg)
      expect(described_class.at_exit_contraindicated?).to be(false)
    end

    it "treats non-hash, non-to_h configs as empty values" do
      cfg = {
        "Lib::X" => Object.new,
      }
      configure_contraindications!(:at_exit => {:stdout_tty => true, :global_silenced => false, :constants_silent => false})
      allow(STDOUT).to receive(:tty?).and_return(true)
      allow(FlossFunding).to receive(:configurations).and_return(cfg)
      expect(described_class.at_exit_contraindicated?).to be(false)
    end

    it "handles Hash configs with non-truthy callables by returning false" do
      cfg = {
        "Lib::Hash" => {"silent_callables" => [-> { false }]},
      }
      configure_contraindications!(:at_exit => {:stdout_tty => true, :global_silenced => false, :constants_silent => false})
      allow(STDOUT).to receive(:tty?).and_return(true)
      allow(FlossFunding).to receive(:configurations).and_return(cfg)
      expect(described_class.at_exit_contraindicated?).to be(false)
    end

    it "handles Hash-like objects with to_h falsey but is_a?(Hash) true to exercise elsif branch" do
      weird = Class.new(Hash) do
        def respond_to?(m, include_all = false)
          return false if m == :to_h
          super
        end
      end
      cfg = {"Lib::Weird" => weird["silent_callables" => [-> { false }]]}
      configure_contraindications!(:at_exit => {:stdout_tty => true, :global_silenced => false, :constants_silent => false})
      allow(STDOUT).to receive(:tty?).and_return(true)
      allow(FlossFunding).to receive(:configurations).and_return(cfg)
      expect(described_class.at_exit_contraindicated?).to be(false)
    end

    it "returns true when a callable raises an error (rescued) due to resulting unknown global state" do
      cfg = {
        "Lib::Two" => {"silent_callables" => [-> { raise "boom" }]},
      }
      configure_contraindications!(:at_exit => {:stdout_tty => true, :global_silenced => false, :constants_silent => false})
      allow(FlossFunding).to receive(:configurations).and_return(cfg)
      expect(described_class.at_exit_contraindicated?).to be(true)
    end
  end
end
