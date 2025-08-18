# frozen_string_literal: true

RSpec.describe "Poke with explicit config_file" do
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
    # specify only the file name; it must reside at the library root
    expect(FlossFunding::ConfigFinder).not_to receive(:find_config_path)

    inclusion = FlossFunding::Inclusion.new(base, nil, __FILE__, {:config_file => ".floss_funding.yml"})
    expect(File.basename(inclusion.config_path)).to eq(".floss_funding.yml")
    expect(inclusion.config_data["funding_donation_uri"]).to eq(["https://floss-funding.dev/donate"])
    expect(inclusion.configuration["funding_donation_uri"]).to eq(["https://floss-funding.dev/donate"])
  end

  it "raises missing library root when including_path is nil even if config_file is provided" do
    expect(FlossFunding::ConfigFinder).not_to receive(:find_config_path)

    expect {
      FlossFunding::Inclusion.new(base, nil, nil, {:config_file => ".floss_funding.yml"})
    }.to raise_error(FlossFunding::Error, /Missing library root path due to: missing including path/)
  end
end
