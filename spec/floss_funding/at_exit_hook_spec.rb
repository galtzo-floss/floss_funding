# frozen_string_literal: true

require "open3"
require "rbconfig"

require "spec_helper"

RSpec.describe "at_exit hook behavior" do
  it "runs FinalSummary at process end and prints a summary header", :check_output do
    ruby = RbConfig.ruby
    lib_dir = File.expand_path("../../lib", __dir__) # project/lib

    script = File.expand_path("../fixtures/at_exit_hook_script.rb", __dir__)

    stdout, stderr, status = Open3.capture3(ruby, "-I", lib_dir, script)

    # Ensure the child process ran successfully
    expect(status.exitstatus).to eq(0), "Child process failed: #{stderr}\nSTDOUT: #{stdout}"

    # Validate at_exit output from the child process (basic behavior)
    expect(stdout).to include("FLOSS Funding Summary:")
    # Expect the table headers to include activated/unactivated
    expect(stdout).to include("activated")
    expect(stdout).to include("unactivated")
  end
end
