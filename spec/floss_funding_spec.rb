# frozen_string_literal: true

RSpec.describe FlossFunding do
  it "has an Error class" do
    expect(described_class::Error.new).to be_a(StandardError)
  end

  it "has FREE_AS_IN_BEER constant" do
    expect(described_class::FREE_AS_IN_BEER).to be_a(String)
  end

  it "has START_MONTH constant" do
    expect(described_class::START_MONTH).to eq(24307)
  end

  it "has BASE_WORDS_PATH constant" do
    expect(File.basename(described_class::BASE_WORDS_PATH)).to eq("base.txt")
  end

  it "defines EIGHT_BYTES as 64" do
    expect(described_class::EIGHT_BYTES).to eq(64)
  end

  it "defines HEX_LICENSE_RULE as a regular expression" do
    expect(described_class::HEX_LICENSE_RULE).to be_a(Regexp)
  end

  it "has FOOTER constant with version" do
    expect(described_class::FOOTER).to include("floss_funding v#{FlossFunding::Version::VERSION}")
  end

  it "has FOOTER constant with solicitation" do
    expect(described_class::FOOTER).to include("Please buy FLOSS \"peace-of-mind\" activation keys to support open source developers.")
  end
end
