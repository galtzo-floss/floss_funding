# frozen_string_literal: true

RSpec.describe FlossFunding::Inclusion do
  describe "#initialize validations and behavior" do
    let(:base) { Module.new }

    before do
      allow(FlossFunding).to receive(:add_or_update_namespace_with_event)
      allow(FlossFunding).to receive(:initiate_begging)
    end

    it "raises when including_path is not a String" do
      expect {
        described_class.new(base, nil, 123)
      }.to raise_error(FlossFunding::Error, /including_path must be a String/)
    end

    it "raises when base has no name" do
      allow(base).to receive(:name).and_return(nil)
      expect {
        described_class.new(base, nil, __FILE__)
      }.to raise_error(FlossFunding::Error, /base must have a name/)
    end

    it "raises when custom_namespace is an empty String" do
      allow(base).to receive(:name).and_return("Pkg::Lib")
      expect {
        described_class.new(base, "", __FILE__)
      }.to raise_error(FlossFunding::Error, /custom_namespace must be nil or a non-empty String/)
    end

    context "when silent is nil" do
      it "creates Namespace, Library, ActivationEvent and registers them" do
        allow(base).to receive(:name).and_return("Pkg::Lib")
        inclusion = described_class.new(base, nil, __FILE__, :silent => nil)
        expect(inclusion.base).to eq(base)
        expect(inclusion.including_path).to eq(__FILE__)
        expect(inclusion.silent).to eq(nil)
        expect(inclusion.namespace).to be_a(FlossFunding::Namespace)
        expect(inclusion.library).to be_a(FlossFunding::Library)
        expect(inclusion.event).to be_a(FlossFunding::ActivationEvent)
      end
    end

    context "when silent callable" do
      it "creates Namespace, Library, ActivationEvent and registers them" do
        allow(base).to receive(:name).and_return("Pkg::Lib")
        callable = ->() { 42 }
        inclusion = described_class.new(base, nil, __FILE__, :silent => callable)
        expect(inclusion.base).to eq(base)
        expect(inclusion.including_path).to eq(__FILE__)
        expect(inclusion.silent).to eq(callable)
        expect(inclusion.namespace).to be_a(FlossFunding::Namespace)
        expect(inclusion.library).to be_a(FlossFunding::Library)
        expect(inclusion.event).to be_a(FlossFunding::ActivationEvent)
      end
    end

    context "when silent is not nil and not callable" do
      it "raises error" do
        allow(base).to receive(:name).and_return("Pkg::Lib")
        expect {
          described_class.new(base, nil, __FILE__, :silent => 42)
        }.to raise_error(FlossFunding::Error, /silent must be nil or respond to call/)
      end
    end
  end
end
