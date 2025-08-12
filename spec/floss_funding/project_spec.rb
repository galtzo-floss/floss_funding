# frozen_string_literal: true

require "floss_funding/project"

RSpec.describe FlossFunding::Project do
  it "exists as a class" do
    expect(defined?(FlossFunding::Project)).to eq("constant")
    expect(FlossFunding::Project).to be_a(Class)
  end
end
