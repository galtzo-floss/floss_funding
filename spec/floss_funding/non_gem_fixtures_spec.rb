# frozen_string_literal: true

RSpec.describe "Non-gem fixtures behavior" do # rubocop:disable RSpec/DescribeClass
  include_context "with stubbed env"

  let(:loader_path) { File.join(__dir__, "../fixtures/non_gems_loader.rb") }

  # Map fixtures with metadata to drive expectations
  let(:fixtures) do
    [
      {:name => "NgBundler1", :enabler => "NG_BUNDLER_1_ENABLE", :bundler => true, :has_yaml => true},
      {:name => "NgBundler2", :enabler => "NG_BUNDLER_2_ENABLE", :bundler => true, :has_yaml => true},
      {:name => "NgBundler3", :enabler => "NG_BUNDLER_3_ENABLE", :bundler => true, :has_yaml => true},
      {:name => "NgBundler4", :enabler => "NG_BUNDLER_4_ENABLE", :bundler => true, :has_yaml => false},
      {:name => "NgBundler5", :enabler => "NG_BUNDLER_5_ENABLE", :bundler => true, :has_yaml => false},
      {:name => "NgPlain1", :enabler => "NG_PLAIN_1_ENABLE", :bundler => false, :has_yaml => true},
      {:name => "NgPlain2", :enabler => "NG_PLAIN_2_ENABLE", :bundler => false, :has_yaml => true},
      {:name => "NgPlain3", :enabler => "NG_PLAIN_3_ENABLE", :bundler => false, :has_yaml => true},
      {:name => "NgPlain4", :enabler => "NG_PLAIN_4_ENABLE", :bundler => false, :has_yaml => false},
      {:name => "NgPlain5", :enabler => "NG_PLAIN_5_ENABLE", :bundler => false, :has_yaml => false},
    ]
  end

  def env_var_for(ns)
    FlossFunding::UnderBar.env_variable_name(ns)
  end

  def remove_fixture_constants
    fixtures.each do |fx|
      Object.send(:remove_const, fx[:name]) if Object.const_defined?(fx[:name]) # rubocop:disable RSpec/RemoveConst
    end
  end

  before do
    # Ensure a clean slate
    remove_fixture_constants
    # Disable all enablers by default
    fixtures.each { |fx| ENV[fx[:enabler]] = "0" }
  end

  it "loads and configures Bundler non-gems correctly (YAML present vs absent)" do
    # Enable only the 5 Bundler fixtures
    fixtures.select { |f| f[:bundler] }.each { |f| ENV[f[:enabler]] = "1" }

    # Silence any prompting by providing valid unpaid activation keys
    activation_env = {}
    fixtures.select { |f| f[:bundler] }.each do |f|
      activation_env[env_var_for(f[:name])] = FlossFunding::FREE_AS_IN_BEER
    end
    stub_env(activation_env)

    # Load the fixtures
    load loader_path

    # Assertions: for Bundler + YAML => suggested_donation_amount contains 7; without YAML => default 5
    fixtures.select { |f| f[:bundler] }.each do |f|
      mod = Object.const_get(f[:name])
      core = mod.const_get(:Core)
      expect(core.respond_to?(:floss_funding_initiate_begging)).to be(true)

      cfg = FlossFunding.configuration(f[:name])
      expect(cfg).to be_a(FlossFunding::Configuration)
      sda = cfg["suggested_donation_amounts"]
      expect(sda).to be_an(Array)
      if f[:has_yaml]
        expect(sda).to include(7)
      else
        # Only defaults (10) should be present
        expect(sda).to include(10)
      end
    end
  end

  it "loads and configures plain non-gems correctly (YAML is honored without project root)" do
    # Enable only the 5 plain fixtures
    fixtures.reject { |f| f[:bundler] }.each { |f| ENV[f[:enabler]] = "1" }

    # Silence any prompting by providing valid unpaid activation keys
    activation_env = {}
    fixtures.reject { |f| f[:bundler] }.each do |f|
      activation_env[env_var_for(f[:name])] = FlossFunding::FREE_AS_IN_BEER
    end
    stub_env(activation_env)

    # Load the fixtures
    load loader_path

    fixtures.reject { |f| f[:bundler] }.each do |f|
      mod = Object.const_get(f[:name])
      core = mod.const_get(:Core)
      expect(core.respond_to?(:floss_funding_initiate_begging)).to be(true)

      cfg = FlossFunding.configuration(f[:name])
      expect(cfg).to be_a(FlossFunding::Configuration)
      sda = cfg["suggested_donation_amounts"]
      expect(sda).to be_an(Array)
      # For plain projects, YAML should be loaded directly if present; otherwise defaults apply
      if f[:has_yaml]
        expect(sda).to include(17)
      else
        expect(sda).to include(10)
      end
    end
  end

  it "handles a script-only fixture with no project root (uses nearest YAML when present or defaults)" do
    # Enable the script-only fixture
    ENV["NG_SCRIPT_ONLY_ENABLE"] = "1"

    # Silent activation for NgScriptOnly
    activation_env = {env_var_for("NgScriptOnly") => FlossFunding::FREE_AS_IN_BEER}
    stub_env(activation_env)

    # Simulate no project root discovered for this script
    allow(FlossFunding::Config).to receive(:find_project_root).and_return(nil)

    # Load the script-only fixture
    script_path = File.join(__dir__, "../fixtures/non_gems/ng_script_only.rb")
    load script_path

    # Verify module and Core were defined and Poke included behavior is available
    mod = Object.const_get("NgScriptOnly")
    core = mod.const_get(:Core)
    expect(core.respond_to?(:floss_funding_initiate_begging)).to be(true)

    # Config should honor nearest YAML within one directory up (spec/fixtures/.floss_funding.yml => 10) when no project root is found
    cfg = FlossFunding.configuration("NgScriptOnly")
    expect(cfg).to be_a(FlossFunding::Configuration)
    sda = cfg["suggested_donation_amounts"]
    expect(sda).to include(10)
  end

  it "handles a script-only fixture with no project root and no YAML nearby)" do
    # Enable the script-only fixture
    ENV["NG_SCRIPT_NO_CONFIG_ENABLE"] = "1"

    # Silent activation for NgScriptNoConfig
    activation_env = {env_var_for("NgScriptNoConfig") => FlossFunding::FREE_AS_IN_BEER}
    stub_env(activation_env)

    # Simulate no project root discovered for this script
    allow(FlossFunding::Config).to receive(:find_project_root).and_return(nil)

    # Load the script-only fixture
    script_path = File.join(__dir__, "../fixtures/non_gems/ng_plain_nothing/ng_script_no_config.rb")
    load script_path

    # Verify module and Core were defined and Poke included behavior is available
    mod = Object.const_get("NgScriptNoConfig")
    core = mod.const_get(:Core)
    expect(core.respond_to?(:floss_funding_initiate_begging)).to be(true)

    # Config should honor nearest YAML within one directory up when no project root is found, but there isn't any YAML
    cfg = FlossFunding.configuration("NgScriptNoConfig")
    expect(cfg).to be_a(FlossFunding::Configuration)
    sda = cfg["suggested_donation_amounts"]
    expect(sda).to include(10)
  end
end
