# frozen_string_literal: true

# Tests for activation_occurrences and related support helpers
# were consolidated into: spec/support/support_helpers_spec.rb
# This file intentionally left minimal.

require "spec_helper"

RSpec.describe "FlossFunding namespaces tracking" do
  it "populates FlossFunding.namespaces when a module includes Poke (smoke)" do
    stub_const("NsTrackSmoke", Module.new)
    NsTrackSmoke.const_set(:Lib, Module.new)

    NsTrackSmoke::Lib.send(:include, FlossFunding::Poke.new(__FILE__))

    spaces = FlossFunding.namespaces
    expect(spaces).to have_key("NsTrackSmoke::Lib")
  end
end
