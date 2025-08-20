# frozen_string_literal: true

# rubocop:disable RSpec/MultipleExpectations, RSpec/VerifiedDoubles, RSpec/MessageSpies

RSpec.describe FlossFunding::Terminal do
  include_context "with stubbed env"

  # Focus on apply_width! behavior and avoid brittle environment coupling for columns

  describe "::apply_width!" do
    it "applies width to a table when columns detected" do
      table = double("table")
      allow(described_class).to receive(:columns).and_return(77)
      expect(table).to receive(:style=).with({:width => 77})
      expect(described_class.apply_width!(table)).to eq(table)
    end

    it "returns table unchanged when errors occur" do
      table = double("table")
      allow(described_class).to receive(:columns).and_raise(StandardError)
      expect(described_class.apply_width!(table)).to eq(table)
    end
  end
end
# rubocop:enable RSpec/MultipleExpectations, RSpec/VerifiedDoubles, RSpec/MessageSpies
