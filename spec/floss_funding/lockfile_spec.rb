# frozen_string_literal: true

# rubocop:disable RSpec/MultipleExpectations, ThreadSafety/DirChdir

require "tmpdir"

RSpec.describe FlossFunding::Lockfile do
  include_context "with stubbed env"

  before do
    FlossFunding::ConfigFinder.clear_caches!
  end

  it "creates the default lockfile under project_root with PID and timestamp" do
    Dir.mktmpdir do |dir|
      # Make tmp dir look like a project root
      File.write(File.join(dir, "Gemfile"), "source 'https://rubygems.org'")
      Dir.chdir(dir) do
        FlossFunding::ConfigFinder.clear_caches!
        expect(FlossFunding::ConfigFinder.project_root).to eq(dir)
        # Use default (no override)
        described_class.install!
        lock_path = File.join(dir, ".floss_funding.lock")
        expect(File).to exist(lock_path)
        lines = File.read(lock_path).split(/\r?\n/)
        expect(lines[0]).to eq(Process.pid.to_s)
        # ISO8601 UTC timestamp on line 2
        expect { Time.iso8601(lines[1]) }.not_to raise_error
      end
    end
  end

  it "resolves ENV override to absolute path" do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "Gemfile"), "gemfile")
      override = File.join(dir, "custom.lock")
      stub_env("FLOSS_FUNDING_CFG_LOCK" => override)
      Dir.chdir(dir) do
        FlossFunding::ConfigFinder.clear_caches!
        described_class.install!
        expect(File).to exist(override)
        described_class.cleanup!
        # cleanup does not delete immediately unless older than threshold; file should remain
        expect(File).to exist(override)
        File.delete(override)
      end
    end
  end

  it "resolves ENV override relative to project_root" do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "gems.rb"), "gemfile")
      rel = File.join("tmp", "nested.lock")
      stub_env("FLOSS_FUNDING_CFG_LOCK" => rel)
      Dir.chdir(dir) do
        FlossFunding::ConfigFinder.clear_caches!
        described_class.install!
        expect(File).to exist(File.join(dir, rel))
        described_class.cleanup!
      end
    end
  end

  it "falls back to default when ENV override is invalid" do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "Gemfile"), "spec")
      stub_env("FLOSS_FUNDING_CFG_LOCK" => "not_a_lock.txt")
      Dir.chdir(dir) do
        FlossFunding::ConfigFinder.clear_caches!
        described_class.install!
        expect(File).to exist(File.join(dir, ".floss_funding.lock"))
        described_class.cleanup!
      end
    end
  end

  it "DEBUG logs when lockfile already exists", :check_output do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "Gemfile"), "gemfile")
      lock_path = File.join(dir, ".floss_funding.lock")
      File.write(lock_path, "99999")
      Dir.chdir(dir) do
        stub_const("FlossFunding::DEBUG", true)
        # Force debug_log to use STDOUT for this example
        stub_env("FLOSS_CFG_FUNDING_LOGFILE" => "")
        FlossFunding.instance_variable_set(:@debug_logger, nil)
        FlossFunding::ConfigFinder.clear_caches!
        expect { described_class.install! }.to output(/Lockfile already present/).to_stdout
        # ensure we don't delete someone else's lock
        described_class.cleanup!
        expect(File).to exist(lock_path)
        File.delete(lock_path)
      end
    end
  end

  it "contraindicates Poke.new when lock exists" do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "Gemfile"), "gemfile")
      Dir.chdir(dir) do
        FlossFunding::ConfigFinder.clear_caches!
        # create lock manually first
        File.write(File.join(dir, ".floss_funding.lock"), "1234")
        # configure environment so other contraindications do not short-circuit
        configure_contraindications!(:poke => {:stdout_tty => true, :ci => false, :global_silenced => false})
        expect(FlossFunding::ContraIndications.poke_contraindicated?).to be(true)
      end
    end
  end

  it "exists? returns false if path resolution raises" do
    allow(described_class).to receive(:path).and_raise(StandardError)
    expect(described_class.exists?).to be(false)
  end

  it "handles file creation failure gracefully" do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "Gemfile"), "gemfile")
      Dir.chdir(dir) do
        FlossFunding::ConfigFinder.clear_caches!
        allow(File).to receive(:open).and_raise(StandardError)
        expect { described_class.install! }.not_to raise_error
        # No file should exist
        expect(File).not_to exist(File.join(dir, ".floss_funding.lock"))
      end
    end
  end

  it "validate_env_lock returns nil when File.expand_path raises" do
    Dir.mktmpdir do |dir|
      allow(File).to receive(:expand_path).and_raise(StandardError)
      expect(described_class.send(:validate_env_lock, "rel/path/test.lock", dir)).to be_nil
    end
  end

  it "owned_by_self? returns false when File.read raises" do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "Gemfile"), "gemfile")
      Dir.chdir(dir) do
        FlossFunding::ConfigFinder.clear_caches!
        path = File.join(dir, ".floss_funding.lock")
        File.write(path, Process.pid.to_s)
        allow(File).to receive(:read).and_raise(StandardError)
        # cleanup! should not raise and should not delete since owned_by_self? => false
        expect { described_class.cleanup! }.not_to raise_error
        expect(File).to exist(path)
        File.delete(path)
      end
    end
  end

  it "cleanup! deletes only when older than threshold and owned" do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "Gemfile"), "gemfile")
      Dir.chdir(dir) do
        FlossFunding::ConfigFinder.clear_caches!
        # Create with current timestamp
        described_class.install!
        path = File.join(dir, ".floss_funding.lock")
        expect(File).to exist(path)
        # With a huge threshold, should NOT delete now
        stub_env("FLOSS_CFG_FUNDING_SEC_PER_NAG_MAX" => "999999")
        described_class.cleanup!
        expect(File).to exist(path)

        # Make it old: rewrite timestamp to long ago
        lines = File.readlines(path)
        lines[1] = Time.utc(2000, 1, 1, 0, 0, 0).iso8601 + "\n"
        File.write(path, lines.join)
        # With small threshold, should delete now
        stub_env("FLOSS_CFG_FUNDING_SEC_PER_NAG_MAX" => "0")
        described_class.cleanup!
        expect(File).not_to exist(path)
      end
    end
  end

  it "at_exit sentinel gating returns a boolean and does not raise" do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "Gemfile"), "gemfile")
      Dir.chdir(dir) do
        FlossFunding::ConfigFinder.clear_caches!
        described_class.install!
        expect { described_class.at_exit_contraindicated? }.not_to raise_error
        val = described_class.at_exit_contraindicated?
        expect([true, false]).to include(val)
      end
    end
  end

  it "at_exit_contraindicated? returns false when lockfile missing" do
    allow(described_class).to receive(:path).and_return(nil)
    expect(described_class.at_exit_contraindicated?).to be(false)
  end

  it "at_exit_contraindicated? executes safely under varied conditions" do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "Gemfile"), "gemfile")
      Dir.chdir(dir) do
        FlossFunding::ConfigFinder.clear_caches!
        described_class.install!
        allow(described_class).to receive(:read_lines_from_path).and_return([Process.pid.to_s, Time.now.utc.iso8601])
        expect([true, false]).to include(described_class.at_exit_contraindicated?)
        allow(described_class).to receive(:read_lines_from_path).and_return(["1", Time.now.utc.iso8601, "2", Time.now.utc.iso8601])
        expect([true, false]).to include(described_class.at_exit_contraindicated?)
      end
    end
  end

  it "at_exit_contraindicated? writes sentinel when only 2 lines present" do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "Gemfile"), "gemfile")
      Dir.chdir(dir) do
        FlossFunding::ConfigFinder.clear_caches!
        described_class.install!
        allow(described_class).to receive(:read_lines_from_path).and_return([Process.pid.to_s, Time.now.utc.iso8601])
        expect(described_class.at_exit_contraindicated?).to be(false)
      end
    end
  end

  it "at_exit_contraindicated? rescues File.open errors and allows once" do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "Gemfile"), "gemfile")
      Dir.chdir(dir) do
        FlossFunding::ConfigFinder.clear_caches!
        described_class.install!
        allow(File).to receive(:open).and_raise(StandardError)
        expect(described_class.at_exit_contraindicated?).to be(false)
      end
    end
  end

  it "age_seconds computes positive age for valid ISO timestamp" do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "Gemfile"), "gemfile")
      Dir.chdir(dir) do
        FlossFunding::ConfigFinder.clear_caches!
        path = File.join(dir, ".floss_funding.lock")
        t = (Time.now.utc - 3).iso8601
        File.open(path, "w") { |f| f.puts("99999\n#{t}\n") }
        expect(described_class.send(:age_seconds, path)).to be >= 2
      end
    end
  end

  it "max_age_seconds falls back on invalid env" do
    stub_env("FLOSS_CFG_FUNDING_SEC_PER_NAG_MAX" => "not_an_int")
    expect(described_class.send(:max_age_seconds)).to eq(600)
  end

  it "cleanup! does not delete when not owned by self" do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "Gemfile"), "gemfile")
      Dir.chdir(dir) do
        FlossFunding::ConfigFinder.clear_caches!
        path = File.join(dir, ".floss_funding.lock")
        File.open(path, "w") { |f| f.puts("99999\n#{Time.now.utc.iso8601}\n") }
        expect(File).to exist(path)
        described_class.send(:cleanup!)
        expect(File).to exist(path)
      end
    end
  end
end
# rubocop:enable RSpec/MultipleExpectations, ThreadSafety/DirChdir
