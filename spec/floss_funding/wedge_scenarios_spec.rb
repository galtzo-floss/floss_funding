# frozen_string_literal: true

require "floss_funding/wedge"

RSpec.describe "Wedge scenario fixtures" do
  SpecStruct = Struct.new(:name, :loaded_from, :full_gem_path)

  def with_load_path(*paths)
    old = $LOAD_PATH.dup
    paths.each { |p| $LOAD_PATH.unshift(p) }
    yield
  ensure
    $LOAD_PATH.replace(old)
  end

  before do
    # Clean up constants that our fixtures may define
    begin
      [:Gem1WithVendored, :VendorGem, :Gem2ExecAndLib, :Gem3ExecAndLibBothPoke, :Gem4WithDummy].each do |const|
        Object.send(:remove_const, const) if Object.const_defined?(const)
      end
    rescue NameError
      # ignore
    end
  end

  let(:fixtures_root) { File.expand_path("../fixtures/scenario_gems", __dir__) }

  it "wedges into real Rainbow gem (ensures real-world require)" do
    # Build a minimal spec list containing rainbow
    specs = [SpecStruct.new("rainbow", nil, nil)]
    allow(FlossFunding::Wedge).to receive(:loaded_specs).and_return(specs)

    # Ensure the Rainbow module is defined for consistent injection regardless of load order
    require "rainbow"

    result = FlossFunding::Wedge.wedge!
    expect(result[:tried]).to eq(1)
    expect(result[:injected]).to eq(1), "Expected injection into Rainbow; details: #{result.inspect}"
    expect(defined?(Rainbow)).to be_truthy
    expect(Rainbow).to respond_to(:floss_funding_fingerprint)
  end

  it "scenario 1: example gem with a vendored gem; both become fingerprinted when wedged" do
    main_lib = File.join(fixtures_root, "gem1_with_vendored", "lib")
    vend_lib = File.join(fixtures_root, "gem1_with_vendored", "vendor", "vendored_lib", "lib")

    with_load_path(main_lib, vend_lib) do
      # Require the main gem file so its module is defined and it tries to require vendored
      require "gem1_with_vendored"

      specs = [
        SpecStruct.new("gem1_with_vendored", nil, nil),
        SpecStruct.new("vendor_gem", nil, nil),
      ]
      allow(FlossFunding::Wedge).to receive(:loaded_specs).and_return(specs)

      result = FlossFunding::Wedge.wedge!
      expect(result[:tried]).to eq(2)
      expect(Gem1WithVendored).to respond_to(:floss_funding_fingerprint)
      expect(VendorGem).to respond_to(:floss_funding_fingerprint)
    end
  end

  it "scenario 2: library with executable alongside; library becomes fingerprinted" do
    lib = File.join(fixtures_root, "gem2_exec_and_lib", "lib")
    with_load_path(lib) do
      require "gem2_exec_and_lib"
      specs = [SpecStruct.new("gem2_exec_and_lib", nil, nil)]
      allow(FlossFunding::Wedge).to receive(:loaded_specs).and_return(specs)
      result = FlossFunding::Wedge.wedge!
      expect(result[:tried]).to eq(1)
      expect(Gem2ExecAndLib).to respond_to(:floss_funding_fingerprint)
    end
  end

  it "scenario 3: library+executable both invoking; wedge still fingerprints library module" do
    lib = File.join(fixtures_root, "gem3_exec_and_lib_both_poke", "lib")
    with_load_path(lib) do
      require "gem3_exec_and_lib_both_poke"
      specs = [SpecStruct.new("gem3_exec_and_lib_both_poke", nil, nil)]
      allow(FlossFunding::Wedge).to receive(:loaded_specs).and_return(specs)
      result = FlossFunding::Wedge.wedge!
      expect(result[:tried]).to eq(1)
      expect(Gem3ExecAndLibBothPoke).to respond_to(:floss_funding_fingerprint)
    end
  end

  it "scenario 4: gem with dummy app subdir; wedge fingerprints the gem namespace" do
    lib = File.join(fixtures_root, "gem4_with_dummy", "lib")
    with_load_path(lib) do
      require "gem4_with_dummy"
      specs = [SpecStruct.new("gem4_with_dummy", nil, nil)]
      allow(FlossFunding::Wedge).to receive(:loaded_specs).and_return(specs)
      result = FlossFunding::Wedge.wedge!
      expect(result[:tried]).to eq(1)
      expect(Gem4WithDummy).to respond_to(:floss_funding_fingerprint)
    end
  end
end
