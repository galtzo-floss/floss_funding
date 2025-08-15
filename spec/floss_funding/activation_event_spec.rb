# frozen_string_literal: true

RSpec.describe FlossFunding::ActivationEvent do
  describe "#initialize" do
    subject(:instance) { described_class.new(lib, key, state, silent) }

    let(:state) { "unactivated" }
    let(:lib) { instance_double("Lib", :namespace => "Ns") }
    let(:key) { "" }
    let(:silent) { nil }

    context "with valid string state, silent=nil" do
      let(:state) { "activated" }

      it "does not raise error" do
        block_is_expected.not_to raise_error
      end

      it "sets state" do
        expect(instance.state).to eq("activated")
      end
    end

    context "with symbol state, silent=nil" do
      let(:state) { :unactivated }

      it "raises error" do
        error = Regexp.escape(%{:unactivated (Symbol) must be one of})
        block_is_expected.to raise_error(FlossFunding::Error, Regexp.new(error))
      end
    end

    context "with invalid string state, silent=nil" do
      let(:state) { "banana" }

      it "raises error" do
        error = Regexp.escape(%{"banana" (String) must be one of})
        block_is_expected.to raise_error(FlossFunding::Error, Regexp.new(error))
      end
    end

    context "with nil state, silent=nil" do
      let(:state) { nil }

      it "raises error" do
        error = Regexp.escape(%{nil (NilClass) must be one of})
        block_is_expected.to raise_error(FlossFunding::Error, Regexp.new(error))
      end
    end

    context "with nil state, silent=42" do
      let(:state) { "activated" }
      let(:silent) { 42 }

      it "raises error" do
        error = Regexp.escape(%{silent must be nil or respond to call})
        block_is_expected.to raise_error(FlossFunding::Error, Regexp.new(error))
      end
    end

    context "with valid string state, silent is callable" do
      let(:silent) { ->() { 42 } }

      it "sets silent to callable" do
        expect(instance.silent.call).to eq(42)
      end
    end

    context "with deterministic time", :deterministic_time => Time.utc(1999, 12, 12, 12, 12, 12) do
      it "sets occurred_at" do
        expect(instance.occurred_at).to eq(Time.utc(1999, 12, 12, 12, 12, 12))
      end
    end
  end
end
