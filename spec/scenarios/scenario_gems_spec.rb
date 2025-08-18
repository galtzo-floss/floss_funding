# frozen_string_literal: true

# rubocop:disable RSpec/DescribeClass, RSpec/BeforeAfterAll, RSpec/MultipleExpectations
require "spec_helper"
require_relative "../support/scenario_gems_generator"

RSpec.describe "Scenario gems fixtures" do
  include_context "with stubbed env"

  let(:root) { File.expand_path("../fixtures/scenario_gems", __dir__) }

  before(:all) do
    # Generate fixtures once per run (idempotent via overwrite in GemMine)
    require_relative "../support/scenario_gems_generator"
    FlossFunding::ScenarioGemsGenerator.generate_all
  end

  before do
    # Clean registry for isolation between examples
    FlossFunding.namespaces = {}
  end

  def add_lib_path(path)
    $LOAD_PATH.unshift(path) unless $LOAD_PATH.include?(path)
  end

  it "gem_with_poked_vendored_gem: only vendored gem is tracked" do
    gem_dir = File.join(root, "gem_with_poked_vendored_gem")
    add_lib_path(File.join(gem_dir, "lib"))

    require "gem_with_poked_vendored_gem"

    names = FlossFunding.all_namespaces.map(&:name)
    expect(names).to include("VendoredGem")
    expect(names).not_to include("GemWithPokedVendoredGem")
  end

  it "poked_gem_with_poked_vendored_gem: both main and vendored gems are tracked" do
    gem_dir = File.join(root, "poked_gem_with_poked_vendored_gem")
    add_lib_path(File.join(gem_dir, "lib"))

    require "poked_gem_with_poked_vendored_gem"

    names = FlossFunding.all_namespaces.map(&:name)
    expect(names).to include("PokedGemWithPokedVendoredGem")
    expect(names).to include("VendoredGem")
  end

  it "poked_gem_with_exe: library tracked when exe is run" do
    gem_dir = File.join(root, "poked_gem_with_exe")
    exe_path = File.join(gem_dir, "bin", "poked_gem_with_exe")
    # Load the script in-process to avoid spawning
    load exe_path

    names = FlossFunding.all_namespaces.map(&:name)
    expect(names).to include("PokedGemWithExe")
  end

  it "poked_gem_with_poked_exe: both library and exe namespace are tracked" do
    gem_dir = File.join(root, "poked_gem_with_poked_exe")
    exe_path = File.join(gem_dir, "bin", "poked_gem_with_poked_exe")
    load exe_path

    names = FlossFunding.all_namespaces.map(&:name)
    expect(names).to include("PokedGemWithPokedExe")
    expect(names).to include("PokedGemWithPokedExeExecutable")
  end

  it "poked_gem_with_dummy_spec_app: app loads the gem and tracks its namespace" do
    gem_dir = File.join(root, "poked_gem_with_dummy_spec_app")
    app_path = File.join(gem_dir, "spec", "dummy", "app.rb")
    load app_path

    names = FlossFunding.all_namespaces.map(&:name)
    expect(names).to include("PokedGemWithDummySpecApp")
  end
end
