# frozen_string_literal: true

RSpec.describe FlossFunding::ContraIndications do
  include_context "with stubbed env"

  describe "::poke_contraindicated?" do
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

    context "with alternative approach" do
      before do
        # Ensure a clean default contraindication state for these tests
        configure_contraindications!
      end

      it "returns true when CI env var is 'true' (case-insensitive)" do
        configure_contraindications!(:poke => {:ci => true})
        expect(described_class.poke_contraindicated?).to be(true)
      end

      it "returns true when Dir.pwd raises StandardError" do
        configure_contraindications!(:poke => {:pwd_raises => true})
        expect(described_class.poke_contraindicated?).to be(true)
      end

      it "returns true when STDOUT.tty? is false (non-TTY)" do
        configure_contraindications!(:poke => {:stdout_tty => false, :ci => false})
        # Ensure our stub is the last one applied for this example
        allow(STDOUT).to receive(:tty?).and_return(false)
        expect(described_class.poke_contraindicated?).to be(true)
      end

      it "returns false when environment is favorable (TTY, not CI, Dir.pwd ok, not silenced)" do
        configure_contraindications!(:poke => {:stdout_tty => true, :ci => false})
        expect(described_class.poke_contraindicated?).to be(false)
      end

      it "returns true when global FlossFunding.silenced is true (early short-circuit)" do
        configure_contraindications!(:poke => {:global_silenced => true})
        expect(described_class.poke_contraindicated?).to be(true)
      end
    end
  end

  describe "::at_exit_contraindicated?" do
    it "returns true when Constants::SILENT is true" do
      configure_contraindications!(:at_exit => {:constants_silent => true, :global_silenced => false, :configurations => {}})
      expect(described_class.at_exit_contraindicated?).to be(true)
    end

    it "handles non-hash non-to_h config entries via else branch as non-silencing" do
      cfg = {
        "Lib::Three" => 123,
      }
      configure_contraindications!(:at_exit => {:stdout_tty => true, :global_silenced => false, :constants_silent => false, :configurations => cfg})
      expect(described_class.at_exit_contraindicated?).to be(false)
    end

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
