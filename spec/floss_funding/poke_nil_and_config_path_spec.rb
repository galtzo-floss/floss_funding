# frozen_string_literal: true

RSpec.describe "Poke with nil including_path and explicit config_path" do
  before do
    allow(FlossFunding).to receive(:add_or_update_namespace_with_event)
    allow(FlossFunding).to receive(:initiate_begging)
  end

  let(:base) do
    mod = Module.new
    allow(mod).to receive(:name).and_return("Pkg::Lib")
    mod
  end

  it "allows including_path = nil and bypasses config search" do
    expect(FlossFunding::ConfigFinder).not_to receive(:find_config_path)

    inclusion = FlossFunding::Inclusion.new(base, nil, nil)
    expect(inclusion.including_path).to be_nil
    # gem_name should not be derived from gemspec (library_root_path will be nil)
    expect(inclusion.library.instance_variable_get(:@library_root_path)).to be_nil
  end

  it "bypasses config search when config_path option is provided (with including_path present)" do
    fixture = File.join(File.dirname(__FILE__), "../fixtures/.floss_funding.yml")
    expect(FlossFunding::ConfigFinder).not_to receive(:find_config_path)

    inclusion = FlossFunding::Inclusion.new(base, nil, __FILE__, nil, {:config_path => fixture})
    lib = inclusion.library
    expect(lib.send(:instance_variable_get, :@config_path)).to eq(fixture)
    expect(lib.config["funding_donation_uri"]).to eq(["https://floss-funding.dev/donate"])
  end

  it "bypasses config search when including_path is nil and config_path is provided" do
    fixture = File.join(File.dirname(__FILE__), "../fixtures/.floss_funding.yml")
    expect(FlossFunding::ConfigFinder).not_to receive(:find_config_path)

    inclusion = FlossFunding::Inclusion.new(base, nil, nil, nil, {:config_path => fixture})
    lib = inclusion.library
    expect(lib.send(:instance_variable_get, :@config_path)).to eq(fixture)
    expect(lib.config["funding_subscription_uri"]).to eq(["https://floss-funding.dev/subscribe"])
    # gem_name fallback when including_path is nil
    expect(lib.gem_name).to eq("Pkg::Lib")
  end
end
