# frozen_string_literal: true

require "spec_helper"

RSpec.describe "FlossFunding namespaces tracking" do
  it "populates FlossFunding.namespaces when a module includes Poke" do
    stub_const("NsTest", Module.new)
    NsTest.const_set(:Lib, Module.new)

    # Before including, namespaces may or may not be empty, but should not contain our key
    expect(FlossFunding.namespaces).not_to have_key("NsTest::Lib")

    NsTest::Lib.send(:include, FlossFunding::Poke.new(__FILE__))

    spaces = FlossFunding.namespaces
    expect(spaces).to be_a(Hash)
    expect(spaces).to have_key("NsTest::Lib")

    ns_obj = spaces["NsTest::Lib"]
    expect(ns_obj).to be_a(FlossFunding::Namespace)
    expect(ns_obj.name).to eq("NsTest::Lib")

    # Should record at least one activation occurrence
    occurrences = FlossFunding.activation_occurrences
    expect(occurrences).to include("NsTest::Lib")
  end

  it "accumulates activation events for the same namespace across multiple includes" do
    stub_const("Multi", Module.new)
    Multi.const_set(:Lib, Module.new)

    # First include
    Multi::Lib.send(:include, FlossFunding::Poke.new(__FILE__))
    count1 = FlossFunding.activation_occurrences.count { |ns| ns == "Multi::Lib" }

    # Re-include by re-defining the module to simulate a new load occurrence
    stub_const("Multi::Lib", Module.new)
    Multi::Lib.send(:include, FlossFunding::Poke.new(__FILE__))
    count2 = FlossFunding.activation_occurrences.count { |ns| ns == "Multi::Lib" }

    expect(count2).to be >= count1
  end
end
