# frozen_string_literal: true

RSpec.describe "Poke with explicit config_path" do
  before do
    allow(FlossFunding).to receive(:add_or_update_namespace_with_event)
    allow(FlossFunding).to receive(:initiate_begging)
  end

  let(:base) do
    mod = Module.new
    allow(mod).to receive(:name).and_return("Pkg::Lib")
    mod
  end

  it "sets up configuration" do
    fixture = File.join(File.dirname(__FILE__), "../fixtures/.floss_funding.yml")
    expect(FlossFunding::ConfigFinder).not_to receive(:find_config_path)

    inclusion = FlossFunding::Inclusion.new(base, nil, __FILE__, {:config_path => fixture})
    expect(inclusion.config_path).to eq(fixture)
    expect(inclusion.config_data["funding_donation_uri"]).to eq(["https://floss-funding.dev/donate"])
    expect(inclusion.configuration["funding_donation_uri"]).to eq(["https://floss-funding.dev/donate"])
  end

  it "bypasses config search when including_path is nil and config_path is provided" do
    fixture = File.join(File.dirname(__FILE__), "../fixtures/.floss_funding.yml")
    expect(FlossFunding::ConfigFinder).not_to receive(:find_config_path)

    expect {
      FlossFunding::Inclusion.new(base, nil, nil, {:config_path => fixture})
    }.to raise_error(FlossFunding::Error, /Missing library root path due to: missing including path/)
  end
end
