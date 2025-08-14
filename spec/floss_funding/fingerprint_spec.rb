# frozen_string_literal: true

RSpec.describe FlossFunding::Fingerprint do
  it "defines a no-op method returning nil" do
    klass = Class.new do
      include FlossFunding::Fingerprint
    end
    expect(klass.new.floss_funding_fingerprint).to be_nil
  end
end
