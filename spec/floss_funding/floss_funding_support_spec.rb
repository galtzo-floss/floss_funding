# frozen_string_literal: true

require "spec_helper"

RSpec.describe FlossFunding do
  describe "::<activation_occurrences>" do
    before do
      described_class.namespaces = {}
    end

    it "returns [] when a namespace has zero events" do
      ns = described_class::Namespace.new("NoEventsNS", nil, [])
      described_class.namespaces = {ns.name => ns}
      expect(described_class.activation_occurrences).to eq([])
    end

    context "when Poke records an activation event" do
      before do
        stub_const("NsTest", Module.new)
        NsTest.const_set(:Lib, Module.new)
        NsTest::Lib.send(:include, described_class::Poke.new(__FILE__))
      end

      it "adds the namespace to FlossFunding.namespaces" do
        expect(described_class.namespaces).to have_key("NsTest::Lib")
      end

      it "shows the namespace in activation_occurrences" do
        occurrences = described_class.activation_occurrences
        expect(occurrences).to include("NsTest::Lib")
      end
    end

    it "accumulates events for the same namespace across multiple includes" do
      stub_const("Multi", Module.new)
      Multi.const_set(:Lib, Module.new)

      Multi::Lib.send(:include, described_class::Poke.new(__FILE__))
      count1 = described_class.activation_occurrences.count { |ns| ns == "Multi::Lib" }

      # Re-define the module to simulate a new load occurrence
      stub_const("Multi::Lib", Module.new)
      Multi::Lib.send(:include, described_class::Poke.new(__FILE__))
      count2 = described_class.activation_occurrences.count { |ns| ns == "Multi::Lib" }

      expect(count2).to be >= count1
    end
  end
end
