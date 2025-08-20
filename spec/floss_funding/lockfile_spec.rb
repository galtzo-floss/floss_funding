# frozen_string_literal: true

# rubocop:disable ThreadSafety/DirChdir

require "tmpdir"
require "yaml"

RSpec.describe FlossFunding::Lockfile do
  include_context "with stubbed env"

  before do
    FlossFunding::ConfigFinder.clear_caches!
  end

  it "creates YAML lockfiles for on_load and at_exit under project_root" do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "Gemfile"), "source 'https://rubygems.org'")
      Dir.chdir(dir) do
        FlossFunding::ConfigFinder.clear_caches!
        expect(FlossFunding::ConfigFinder.project_root).to eq(dir)

        # Access the lockfiles to initialize and persist them
        described_class.on_load
        described_class.at_exit
        on_load_path = File.join(dir, ".floss_funding.ruby.on_load.lock")
        at_exit_path = File.join(dir, ".floss_funding.ruby.at_exit.lock")

        expect(File).to exist(on_load_path)
        expect(File).to exist(at_exit_path)

        on_load = YAML.safe_load(File.read(on_load_path))
        at_exit = YAML.safe_load(File.read(at_exit_path))

        expect(on_load.dig("created", "type")).to eq("on_load")
        expect(at_exit.dig("created", "type")).to eq("at_exit")
        expect(on_load).to have_key("nags")
        expect(at_exit).to have_key("nags")
      end
    end
  end

  it "records on_load nag once per library within lifetime" do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "Gemfile"), "gemfile")
      Dir.chdir(dir) do
        FlossFunding::ConfigFinder.clear_caches!
        # Access the lockfiles to initialize and persist them
        described_class.on_load

        # Build a minimal fake library/event
        ns = FlossFunding::Namespace.new("My::Lib", Module.new)
        lib = FlossFunding::Library.new("my_lib", ns, nil, "My::Lib", __FILE__, dir, nil, ns.env_var_name, FlossFunding::Configuration.new({}), nil)
        evt = FlossFunding::ActivationEvent.new(lib, nil, FlossFunding::STATES[:unactivated], nil)

        lock = described_class.on_load
        expect(lock.nagged?("my_lib")).to be(false)
        lock.record_nag(lib, evt, "on_load")
        expect(lock.nagged?("my_lib")).to be(true)
        # second record should be ignored
        lock.record_nag(lib, evt, "on_load")
        expect(lock.nagged?("my_lib")).to be(true)
      end
    end
  end

  it "enforces min/max bounds on lockfile lifetimes via env" do
    # too small -> coerced to 600
    stub_env("FLOSS_CFG_FUNDING_ON_LOAD_SEC_PER_NAG_MAX" => "1")
    ol = described_class.on_load
    expect(ol.send(:send, :max_age_seconds)).to eq(600)

    # too large -> capped at 7 days
    stub_env("FLOSS_CFG_FUNDING_AT_EXIT_SEC_PER_NAG_MAX" => 10_000_000.to_s)
    ae = described_class.at_exit
    expect(ae.send(:send, :max_age_seconds)).to eq(604_800)
  end
end
# rubocop:enable ThreadSafety/DirChdir
