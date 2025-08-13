# frozen_string_literal: true

require "floss_funding/inclusion"

RSpec.describe FlossFunding::Inclusion do
  it "exists as a class" do
    expect(defined?(FlossFunding::Inclusion)).to eq("constant")
    expect(FlossFunding::Inclusion).to be_a(Class)
  end
end
