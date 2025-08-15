# frozen_string_literal: true

# Wedge is not loaded by default, so we need to require it explicitly
require "floss_funding/wedge"

RSpec.describe FlossFunding::Wedge do
  include_context 'with stubbed env'

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
    it "uses Gem.loaded_specs when it returns a hash" do
      allow(Gem).to receive(:loaded_specs).and_return({"a" => 1, "b" => 2})
      expect(described_class.loaded_specs).to match_array([1, 2])
    end

    it "uses Gem.loaded_specs when it returns an array" do
      allow(Gem).to receive(:loaded_specs).and_return([1, 2])
      expect(described_class.loaded_specs).to match_array([1, 2])
    end

    it "rescues and returns [] if Gem.loaded_specs raises" do
      allow(Gem).to receive(:loaded_specs).and_raise(StandardError)
      expect(described_class.loaded_specs).to eq([])
    end

    it "rescues unexpected errors after retrieval (outer rescue)" do
      obj = Object.new
      def obj.respond_to?(*); raise "oops"; end
      allow(Gem).to receive(:loaded_specs).and_return(obj)
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

    it "returns nil when const_get fails on a later part" do
      module Tricky; def self.const_defined?(*); true; end; def self.const_get(*); raise "nope"; end; end
      expect(described_class.safe_const_resolve("Tricky::X")).to be_nil
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

  describe "skip logic for specs" do
    it "skips self (floss_funding) and only tries others" do
      module Zed; end
      specs = [
        SpecStruct.new("floss_funding", nil, nil),
        SpecStruct.new("zed", nil, nil),
      ]
      allow(described_class).to receive(:loaded_specs).and_return(specs)
      result = described_class.wedge!
      expect(result[:tried]).to eq(1)
    end

    it "skips invalid specs (empty name) via valid_spec?" do
      module Yak; end
      bad = SpecStruct.new("", nil, nil)
      good = SpecStruct.new("yak", nil, nil)
      allow(described_class).to receive(:loaded_specs).and_return([bad, good])
      result = described_class.wedge!
      expect(result[:tried]).to eq(1)
    end
  end


  describe ".attempt_require_for_spec branches" do
    it "tolerates empty spec name and ignores invalid candidate entries" do
      spec = SpecStruct.new(nil, nil, nil)
      # include both invalid and valid candidate shapes
      candidates = [nil, "", "Foo::Bar"]
      expect {
        described_class.send(:attempt_require_for_spec, spec, candidates)
      }.not_to raise_error
    end
  end

  describe ".safe_const_resolve positive" do
    it "resolves existing constants" do
      module A; module B; end; end
      expect(described_class.safe_const_resolve("A::B")).to eq(A::B)
    end
  end

  describe ".valid_spec? checks" do
    it "returns true for a valid spec-like object" do
      spec = SpecStruct.new("ok", nil, nil)
      expect(described_class.send(:valid_spec?, spec)).to be true
    end

    it "returns false for invalid spec (no name)" do
      spec = SpecStruct.new(nil, nil, nil)
      expect(described_class.send(:valid_spec?, spec)).to be false
    end
  end

  describe "render_summary_table variants" do
    it "falls back when terminal-table cannot be required (LoadError)" do
      hide_const("Terminal::Table")
      allow(Kernel).to receive(:require).with("terminal-table").and_raise(LoadError)
      out = described_class.send(:render_summary_table, {:details => [], :tried => 0, :injected => 0})
      expect(out).to start_with("[Wedge] Summary:")
    end
    let(:results) do
      {
        :tried => 2,
        :injected => 1,
        :details => [
          {:gem => "empty_gem", :injected_into => []},
          {:gem => "good_gem", :injected_into => ["Good::Mod"]},
        ],
      }
    end

    it "excludes gems with no injections from the table" do
      out = described_class.send(:render_summary_table, results)
      expect(out).not_to include("empty_gem")
      expect(out).to include("good_gem")
    end

    it "renders a table string when Terminal::Table is available" do
      out = described_class.send(:render_summary_table, results)
      expect(out).to include("[Wedge] Summary")
      expect(out).to include("good_gem")
    end

    it "rescues StandardError during table rendering and falls back" do
      stub_const("Terminal::Table", Class.new do
        def initialize(*); raise "boom"; end
        def to_s; "IGNORED"; end
      end)
      out = described_class.send(:render_summary_table, results)
      expect(out).to include("[Wedge] Summary:")
    end
  end

  describe "wedge! output branches", :check_output do
    it "prints raw results when DEBUG is true" do
      stub_const("FlossFunding::DEBUG", true)
      module Qux; end
      specs = [SpecStruct.new("qux", nil, nil)]
      allow(described_class).to receive(:loaded_specs).and_return(specs)
      expect { described_class.wedge! }.to output(include("[Wedge] Finished wedge!").and(include("{tried:")).and(include("details"))).to_stdout
    end

    it "prints summary table when DEBUG is false" do
      stub_const("FlossFunding::DEBUG", false)
      module Vim; end
      specs = [SpecStruct.new("vim", nil, nil)]
      allow(described_class).to receive(:loaded_specs).and_return(specs)
      # Ensure table fallback path is available and deterministic
      allow(Kernel).to receive(:require).with("terminal-table").and_raise(LoadError)
      expect { described_class.wedge! }.to output(/\[Wedge\] Summary:/).to_stdout
    end
  end

  describe "error handling during include" do
    it "swallows errors raised during include attempt and continues" do
      module Boom; end
      specs = [SpecStruct.new("boom", nil, nil)]
      allow(described_class).to receive(:loaded_specs).and_return(specs)
      # Make Poke.new raise to simulate include failure
      allow(FlossFunding::Poke).to receive(:new).and_raise("kaboom")
      result = described_class.wedge!
      detail = result[:details].find { |d| d[:gem] == "boom" }
      expect(detail[:injected_into]).to eq([])
    end
  end

  describe "DANGEROUS branch" do
    it "invokes attempt_require_for_spec when DANGEROUS is true" do
      stub_const("FlossFunding::Wedge::DANGEROUS", true)
      module Rrr; end
      spec = SpecStruct.new("rrr", nil, nil)
      allow(described_class).to receive(:loaded_specs).and_return([spec])
      expect(described_class).to receive(:attempt_require_for_spec).with(spec, kind_of(Array))
      described_class.wedge!
    end
  end

  # DANGEROUS will go untested for now. It's in the name. It's not a toy.
  # describe "DANGEROUS configuration at load time" do
  #   def reload_wedge_with(danger_env: nil, debug: false)
  #     # Ensure clean load of the file so the constant is re-evaluated
  #     hide_const("FlossFunding::Wedge") if defined?(FlossFunding::Wedge)
  #     stub_const("FlossFunding::DEBUG", debug)
  #     # Control the ENV that gate-keeps DANGEROUS
  #     stub_env("FLOSS_FUNDING_WEDGE_DANGEROUS" => danger_env)
  #     load File.expand_path("../../../lib/floss_funding/wedge.rb", __FILE__)
  #     # Touch a few methods to ensure SimpleCov sees this file as executed after reload.
  #     # This counters the Ruby Coverage quirk where Kernel#load can wipe prior counts.
  #     begin
  #       FlossFunding::Wedge.namespace_candidates_for("google-cloud-storage")
  #       FlossFunding::Wedge.safe_const_resolve("Nope::Thing")
  #       FlossFunding::Wedge.send(:camelize, "alpha_beta")
  #       FlossFunding::Wedge.send(:valid_spec?, Struct.new(:name).new("ok"))
  #       FlossFunding::Wedge.send(:render_summary_table, {:tried => 0, :injected => 0, :details => []})
  #       FlossFunding::Wedge.send(:guess_including_path, Struct.new(:full_gem_path).new(Dir.pwd))
  #     rescue StandardError
  #       # best-effort warm-up; ignore any failures
  #     end
  #     FlossFunding::Wedge
  #   end
  #
  #   it "defaults to false when ENV is unset" do
  #     mod = reload_wedge_with(danger_env: nil, debug: true)
  #     expect(mod::DANGEROUS).to be false
  #   end
  #
  #   it "is true when ENV=1 and DEBUG=true" do
  #     mod = reload_wedge_with(danger_env: "1", debug: true)
  #     expect(mod::DANGEROUS).to be true
  #   end
  #
  #   it "warns and is false when ENV=1 and DEBUG=false" do
  #     expect {
  #       mod = reload_wedge_with(danger_env: "1", debug: false)
  #       expect(mod::DANGEROUS).to be false
  #     }.to output(/Unable to use DANGEROUS mode because DEBUG=false/).to_stderr
  #   end
  #
  #   it "is false for other truthy-like values (e.g., 'true') even with DEBUG=true" do
  #     mod = reload_wedge_with(danger_env: "true", debug: true)
  #     expect(mod::DANGEROUS).to be false
  #   end
  # end

  describe ".attempt_require_for_spec paths" do
    it "with DEBUG logging executes require paths" do
      stub_const("FlossFunding::DEBUG", true)
      spec = SpecStruct.new("no-such-gem-xyz", nil, nil)
      expect {
        described_class.send(:attempt_require_for_spec, spec, ["NoSuch::Gem"]) 
      }.not_to raise_error
    end

    it "logs a successful require path when DEBUG is true" do
      stub_const("FlossFunding::DEBUG", true)
      spec = SpecStruct.new("json", nil, nil)
      expect {
        described_class.send(:attempt_require_for_spec, spec, ["Json"]) 
      }.not_to raise_error
    end
    it "does not raise and attempts various require strings" do
      spec = SpecStruct.new("foo-bar_baz", nil, nil)
      candidates = ["Foo::BarBaz"]
      expect {
        described_class.send(:attempt_require_for_spec, spec, candidates)
      }.not_to raise_error
    end

    it "handles objects without a name method (respond_to? false)" do
      spec = Object.new
      expect {
        described_class.send(:attempt_require_for_spec, spec, ["Foo::Bar"])
      }.not_to raise_error
    end
  end
end
