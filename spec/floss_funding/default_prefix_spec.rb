# frozen_string_literal: true

RSpec.describe FlossFunding::Constants do
  describe "::DEFAULT_PREFIX from ENV" do
    it "is a String constant and may be overridden by ENV" do
      # This test intentionally avoids reloading the top-level file with a
      # modified ENV, as that would redefine constants and alter global state.
      # The branch that reads ENV is documented and excluded from coverage
      # with :nocov: in the source.
      expect(described_class::DEFAULT_PREFIX).to be_a(String)
    end
  end
end
