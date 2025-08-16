# frozen_string_literal: true

RSpec.describe "Errored inert mode" do
  include_context "with stubbed env"

  before do
    # ensure clean slate
    FlossFunding.namespaces = {}
    FlossFunding.silenced = false
  end

  it "causes poke to be contraindicated when errored? is true" do
    allow(FlossFunding).to receive(:errored?).and_return(true)
    expect(FlossFunding::ContraIndications.poke_contraindicated?).to be(true)
  end

  it "causes at_exit to be contraindicated when errored? is true" do
    allow(FlossFunding).to receive(:errored?).and_return(true)
    expect(FlossFunding::ContraIndications.at_exit_contraindicated?).to be(true)
  end
end
