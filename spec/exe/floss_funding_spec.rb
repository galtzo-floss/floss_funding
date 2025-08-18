# frozen_string_literal: true

require "open3"

RSpec.describe "exe/floss_funding" do
  let(:exe_path) { File.expand_path("../../exe/floss_funding", __dir__) }

  # Helper to run the CLI in a clean subprocess from the project root
  def run_cli(*args, env: {})
    # Use Bundler to ensure the same dependency context as the development environment
    default_env = {
      "BUNDLE_GEMFILE" => File.expand_path("../../Gemfile", __dir__),
    }
    cmd = ["bundle", "exec", RbConfig.ruby, exe_path, *args]
    Open3.capture3(default_env.merge(env), *cmd, :chdir => File.expand_path("../..", __dir__))
  end

  describe "--help" do
    it "prints usage and exits 0" do
      stdout, stderr, status = run_cli("--help")
      expect(status.exitstatus).to eq(0), "stderr: #{stderr}\nstdout: #{stdout}"
      expect(stderr).to eq("")
      expect(stdout).to include("Usage: floss_funding [options]")
    end
  end

  describe "--version" do
    it "prints version and exits 0" do
      require "floss_funding/version"
      stdout, stderr, status = run_cli("--version")
      expect(status.exitstatus).to eq(0), "stderr: #{stderr}\nstdout: #{stdout}"
      expect(stderr).to eq("")
      # Output is just the version and a newline
      expect(stdout.strip).to eq(FlossFunding::Version::VERSION)
    end
  end

  describe "no arguments" do
    it "prints usage and exits 0" do
      stdout, stderr, status = run_cli
      expect(status.exitstatus).to eq(0), "stderr: #{stderr}\nstdout: #{stdout}"
      expect(stderr).to eq("")
      expect(stdout).to include("Usage: floss_funding [options]")
    end
  end

  describe "invalid option" do
    it "prints error and usage to STDERR and exits 1" do
      stdout, stderr, status = run_cli("--nope")
      expect(status.exitstatus).to eq(1)
      expect(stdout).to eq("")
      expect(stderr).to include("invalid option")
      expect(stderr).to include("Usage: floss_funding [options]")
    end
  end

  describe "short options" do
    it "supports -lan as alias for --list-activated-namespaces" do
      stdout, stderr, status = run_cli("-lan")
      expect(status.exitstatus).to eq(0), "stderr: #{stderr}\nstdout: #{stdout}"
      expect(stderr).to eq("")
      expect(stdout).to include("Activated Namespaces:")
    end

    it "supports -p as alias for --progress" do
      stdout, stderr, status = run_cli("-p")
      expect(status.exitstatus).to eq(0), "stderr: #{stderr}\nstdout: #{stdout}"
      expect(stderr).to eq("")
      # Progress may print a bar or fallback text; assert on a stable prefix
      expect(stdout).to match(/Funding:|Progress|Activated vs/)
    end

    it "shows 0% when 0 of 1 libraries are activated (no false 100%)" do
      stdout, stderr, status = run_cli("-p")
      expect(status.exitstatus).to eq(0), "stderr: #{stderr}\nstdout: #{stdout}"
      expect(stderr).to eq("")
      # In a typical repo with no activation keys, floss_funding itself is unactivated: 0/1
      # Ensure it does not incorrectly show 100%
      expect(stdout).to include("(0/1)")
      expect(stdout).not_to include("100% (1/1)")
    end
  end

  describe "--table" do
    it "prints a two-pane table and exits 0" do
      stdout, stderr, status = run_cli("-t")
      expect(status.exitstatus).to eq(0), "stderr: #{stderr}\nstdout: #{stdout}"
      expect(stderr).to eq("")
      expect(stdout).to include("Needs Funding (Unactivated + Invalid)")
      expect(stdout).to include("Funded by You (Activated)")
    end
  end

  describe "--wedge" do
    it "attempts to inject and prints a summary" do
      stdout, stderr, status = run_cli("--wedge")
      expect([0, 2]).to include(status.exitstatus), "stderr: #{stderr}\nstdout: #{stdout}"
      expect(stderr).to eq("")
      expect(stdout).to match(/Wedge summary: tried=\d+ gems, injected=\d+/)
    end
  end
end
