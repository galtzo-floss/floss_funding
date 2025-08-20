# frozen_string_literal: true

# rubocop:disable RSpec/MultipleExpectations

RSpec.describe FlossFunding::Constants do
  include_context "with stubbed env"

  let(:constants_path) { File.expand_path("../../lib/floss_funding/constants.rb", __dir__) }

  def reload_constants!
    hide_const("FlossFunding::Constants") if defined?(FlossFunding::Constants)
    load constants_path
  end

  it "sets SILENT=false by default (no env)" do
    stub_env("FLOSS_CFG_FUND_SILENT" => nil)
    reload_constants!
    expect(FlossFunding::Constants::SILENT).to be(false)
  end

  it "sets SILENT=true when env matches (case-insensitive exact)" do
    stub_env("FLOSS_CFG_FUND_SILENT" => "CATHEDRAL_OR_BAZAAR")
    reload_constants!
    expect(FlossFunding::Constants::SILENT).to be(true)

    stub_env("FLOSS_CFG_FUND_SILENT" => "cathedral_or_bazaar")
    reload_constants!
    expect(FlossFunding::Constants::SILENT).to be(true)
  end

  it "sets SILENT=false for other values" do
    stub_env("FLOSS_CFG_FUND_SILENT" => "nope")
    reload_constants!
    expect(FlossFunding::Constants::SILENT).to be(false)
  end
end
# rubocop:enable RSpec/MultipleExpectations
