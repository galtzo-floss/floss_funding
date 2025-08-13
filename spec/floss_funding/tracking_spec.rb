# frozen_string_literal: true

require "open3"
require "rbconfig"

require "spec_helper"
require_relative "../fixtures/traditional_test"

RSpec.describe "FlossFunding tracking functionality" do
  include_context "with stubbed env"

  # No mutable lists to reset; lists are computed from activation events

  describe "tracking libraries" do
    it "tracks activated libraries" do
      # Use an unpaid activation key for silent activation
      valid_key = FlossFunding::FREE_AS_IN_BEER

      stub_env("FLOSS_FUNDING_TRADITIONAL_TEST_INNER_MODULE" => valid_key)
      # Freeze time to August 2125
      Timecop.freeze(Time.new(2125, 8, 1)) do
        # Include the Poke module
        stub_const("TraditionalTest::InnerModule", Module.new)
        TraditionalTest::InnerModule.send(:include, FlossFunding::Poke.new(__FILE__))

        # Check that the module was added to the activated list
        expect(FlossFunding.activated_namespace_names).to include("TraditionalTest::InnerModule")
        expect(FlossFunding.unactivated_namespace_names).not_to include("TraditionalTest::InnerModule")
      end
    end

    it "tracks unactivated libraries" do
      # No activation key set
      stub_env("FLOSS_FUNDING_TRADITIONAL_TEST_INNER_MODULE" => nil)
      # Capture stdout to prevent output during tests
      capture(:stdout) do
        # Include the Poke module
        stub_const("TraditionalTest::InnerModule", Module.new)
        TraditionalTest::InnerModule.send(:include, FlossFunding::Poke.new(__FILE__))
      end

      # Check that the module was added to the unactivated list
      expect(FlossFunding.unactivated_namespace_names).to include("TraditionalTest::InnerModule")
      expect(FlossFunding.activated_namespace_names).not_to include("TraditionalTest::InnerModule")
    end

    it "tracks libraries with unpaid silence activation keys" do
      # Set up an unpaid silence activation key
      stub_env("FLOSS_FUNDING_TRADITIONAL_TEST_INNER_MODULE" => FlossFunding::FREE_AS_IN_BEER)
      # Include the Poke module
      stub_const("TraditionalTest::InnerModule", Module.new)
      TraditionalTest::InnerModule.send(:include, FlossFunding::Poke.new(__FILE__))

      # Check that the module was added to the activated list
      expect(FlossFunding.activated_namespace_names).to include("TraditionalTest::InnerModule")
      expect(FlossFunding.unactivated_namespace_names).not_to include("TraditionalTest::InnerModule")
    end
  end

  describe "multithreaded tracking" do
    it "correctly tracks libraries when included from multiple threads and covers all mutex branches" do
      # Use an unpaid activation key for silent activation
      valid_key = FlossFunding::FREE_AS_IN_BEER

      stub_env("FLOSS_FUNDING_TRADITIONAL_TEST_INNER_MODULE" => valid_key)
      # Freeze time to August 2125
      Timecop.freeze(Time.new(2125, 8, 1)) do
        # Create two modules for testing
        stub_const("TraditionalTest::InnerModule", Module.new)
        stub_const("TraditionalTest::OtherModule", Module.new)

        # Prepare to exercise configuration merging branches
        # First set gives :namespace only; second set adds :custom_namespaces
        thread1 = Thread.new do
          # Include for one module
          TraditionalTest::InnerModule.send(:include, FlossFunding::Poke.new(__FILE__))
        end

        thread2 = Thread.new do
          # No activation key for the second module
          TraditionalTest::OtherModule.send(:include, FlossFunding::Poke.new(__FILE__))
        end

        # Wait for both threads to complete
        thread1.join
        thread2.join

        # Check that both modules were tracked correctly
        expect(FlossFunding.activated_namespace_names).to include("TraditionalTest::InnerModule")
        expect(FlossFunding.unactivated_namespace_names).to include("TraditionalTest::OtherModule")

        # Ensure env var names are derived and present for both namespaces
        names = FlossFunding.env_var_names
        expect(names["TraditionalTest::InnerModule"]).to eq(FlossFunding::UnderBar.env_variable_name("TraditionalTest::InnerModule"))
        expect(names["TraditionalTest::OtherModule"]).to eq(FlossFunding::UnderBar.env_variable_name("TraditionalTest::OtherModule"))

        # Validate configurations are available and include gem_name entries
        merged_config = FlossFunding.configurations("TraditionalTest::InnerModule")
        expect(merged_config).to be_a(FlossFunding::Configuration)
        expect(Array(merged_config["gem_name"]).compact).to include("floss_funding")

        # Exercise base_words early return branch
        expect(FlossFunding.base_words(0)).to eq([])
      end
    end
  end

  # describe "END hook" do
  #   it "outputs the correct emoji for activated and unactivated libraries via real process", :check_output do
  #     ruby = RbConfig.ruby
  #     lib_dir = File.expand_path("../../lib", __dir__) # project/lib
  #
  #     script = File.expand_path("../fixtures/end_hook_script.rb", __dir__)
  #
  #     stdout, stderr, status = Open3.capture3(ruby, "-I", lib_dir, script, lib_dir)
  #
  #     # Ensure the child process ran successfully
  #     expect(status.exitstatus).to eq(0), "Child process failed: #{stderr}\nSTDOUT: #{stdout}"
  #
  #     # Validate actual at_exit output from the child process
  #     expect(stdout).to include("FLOSS Funding Summary:")
  #     expect(stdout).to include("Activated libraries (2): ⭐️⭐️") # One of them is FlossFunding!
  #     expect(stdout).to include("Unactivated libraries (1): 🫥")
  #   end
  # end
end
