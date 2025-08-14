# frozen_string_literal: true

RSpec.describe FlossFunding::Wedge do
  # Build a minimal spec-like struct for stubbing
  SpecStruct = Struct.new(:name, :loaded_from, :full_gem_path)

  before do
    # Ensure clean constants before each test
    Object.send(:remove_const, :Foo) if Object.const_defined?(:Foo)
    Object.send(:remove_const, :AlphaBeta) if Object.const_defined?(:AlphaBeta)
  rescue NameError
    # ignore
  end

  it "injects Poke into nested module candidates from dashed gem names" do
    # Define Foo::Bar
    module Foo
      module Bar; end
    end

    specs = [
      SpecStruct.new("foo-bar", File.join(Dir.pwd, "foo-bar.gemspec"), Dir.pwd),
    ]

    # Stub loaded specs to our controlled list
    allow(described_class).to receive(:loaded_specs).and_return(specs)

    result = described_class.wedge!

    expect(Foo::Bar).to respond_to(:floss_funding_fingerprint)
    expect(result[:tried]).to eq(1)
    # Injected into at least one namespace for that gem
    expect(result[:injected]).to eq(1)
    expect(result[:details].first[:injected_into]).to include("Foo::Bar").or include("Foo")
  end

  it "injects Poke into collapsed CamelCase candidates from underscored gem names" do
    module AlphaBeta; end

    specs = [
      SpecStruct.new("alpha_beta", File.join(Dir.pwd, "alpha_beta.gemspec"), Dir.pwd),
    ]

    allow(described_class).to receive(:loaded_specs).and_return(specs)

    result = described_class.wedge!

    expect(AlphaBeta).to respond_to(:floss_funding_fingerprint)
    expect(result[:tried]).to eq(1)
    expect(result[:injected]).to eq(1)
    expect(result[:details].first[:injected_into]).to include("AlphaBeta")
  end

  it "skips gems with no resolvable constants without raising" do
    specs = [
      SpecStruct.new("nonexistent_gem_module_name", File.join(Dir.pwd, "nope.gemspec"), Dir.pwd),
    ]
    allow(described_class).to receive(:loaded_specs).and_return(specs)

    expect { described_class.wedge! }.not_to raise_error
    # Nothing was injected, but it was tried
    result = described_class.wedge!
    expect(result[:tried]).to eq(1)
    expect(result[:injected]).to eq(0)
    expect(result[:details].first[:injected_into]).to eq([])
  end

  describe ".loaded_specs variants" do
    it "uses Bundler.rubygems.loaded_specs when available (hash)" do
      rubygems = double("RG", :loaded_specs => {"a" => 1, "b" => 2})
      bundler = double("Bundler", :rubygems => rubygems)
      stub_const("Bundler", bundler)
      expect(described_class.loaded_specs).to match_array([1, 2])
    end

    it "uses Bundler.rubygems.loaded_specs when available (array)" do
      rubygems = double("RG", :loaded_specs => [1, 2])
      bundler = double("Bundler", :rubygems => rubygems)
      stub_const("Bundler", bundler)
      expect(described_class.loaded_specs).to match_array([1, 2])
    end

    it "falls back to Gem.loaded_specs when Bundler lacks rubygems" do
      stub_const("Bundler", Module.new) # defined, but no rubygems method
      allow(Gem).to receive(:loaded_specs).and_return({"x" => 9, "y" => 8})
      expect(described_class.loaded_specs).to eq([9, 8])
    end

    it "rescues and returns [] if an error occurs" do
      rubygems = double("RG")
      allow(rubygems).to receive(:loaded_specs).and_raise(StandardError)
      bundler = double("Bundler", :rubygems => rubygems)
      stub_const("Bundler", bundler)
      expect(described_class.loaded_specs).to eq([])
    end
  end

  describe ".namespace_candidates_for edge cases" do
    it "returns [] for nil and empty" do
      expect(described_class.namespace_candidates_for(nil)).to eq([])
      expect(described_class.namespace_candidates_for("")).to eq([])
    end

    it "returns nested and collapsed candidates for multi-part names" do
      c = described_class.namespace_candidates_for("google-cloud-storage")
      expect(c).to include("Google::Cloud::Storage", "Google::Cloud", "Google", "GoogleCloudStorage")
      # Ensure uniq and proper ordering with nested path first
      expect(c.first).to eq("Google::Cloud::Storage")
    end
  end

  describe ".safe_const_resolve variants" do
    it "returns nil for nil or empty path" do
      expect(described_class.safe_const_resolve(nil)).to be_nil
      expect(described_class.safe_const_resolve("")).to be_nil
    end

    it "returns nil when an intermediate constant is missing" do
      expect(described_class.safe_const_resolve("Nope::Thing")).to be_nil
    end
  end

  describe "including path guesses" do
    it "uses gemspec from full_gem_path when present" do
      require "tmpdir"
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "fake.gemspec"), "spec")
        spec = SpecStruct.new("fake", nil, dir)
        # Call private via send
        path = described_class.send(:guess_including_path, spec)
        expect(path).to end_with("fake.gemspec")
      end
    end

    it "falls back to __FILE__ when no gemspec present" do
      spec = SpecStruct.new("fake", nil, Dir.pwd)
      allow(Dir).to receive(:glob).and_return([])
      path = described_class.send(:guess_including_path, spec)
      expect(path).to eq(FlossFunding::Wedge.method(:guess_including_path).source_location.first)
    end
  end

  describe "camelize edge cases" do
    it "handles underscores and empty segments" do
      # private method
      expect(described_class.send(:camelize, "alpha_beta")).to eq("AlphaBeta")
      expect(described_class.send(:camelize, "__")).to eq("")
      expect(described_class.send(:camelize, "a__b")).to eq("AB")
    end
  end
end
