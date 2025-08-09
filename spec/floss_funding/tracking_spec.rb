# frozen_string_literal: true

require "open3"
require "rbconfig"

require "spec_helper"
require_relative "../fixtures/traditional_test"

RSpec.describe "FlossFunding tracking functionality" do
  # Reset the licensed and unlicensed lists before each test
  before do
    FlossFunding.licensed = []
    FlossFunding.unlicensed = []
  end

  describe "tracking libraries" do
    it "tracks licensed libraries" do
      # Set up a valid license key
      valid_key = "161A84A3F7383B5BEA81BA1A0B71EA558D987012BE0A07087961F96AC72CF777"

      stubbed_env("FLOSS_FUNDING_TRADITIONAL_TEST_INNER_MODULE" => valid_key) do
        # Freeze time to August 2125
        Timecop.freeze(Time.new(2125, 8, 1)) do
          # Include the Poke module
          stub_const("TraditionalTest::InnerModule", Module.new)
          TraditionalTest::InnerModule.send(:include, FlossFunding::Poke.new(__FILE__))

          # Check that the module was added to the licensed list
          expect(FlossFunding.licensed).to include("TraditionalTest::InnerModule")
          expect(FlossFunding.unlicensed).not_to include("TraditionalTest::InnerModule")
        end
      end
    end

    it "tracks unlicensed libraries" do
      # No license key set
      stubbed_env("FLOSS_FUNDING_TRADITIONAL_TEST_INNER_MODULE" => nil) do
        # Capture stdout to prevent output during tests
        capture(:stdout) do
          # Include the Poke module
          stub_const("TraditionalTest::InnerModule", Module.new)
          TraditionalTest::InnerModule.send(:include, FlossFunding::Poke.new(__FILE__))
        end
      end

      # Check that the module was added to the unlicensed list
      expect(FlossFunding.unlicensed).to include("TraditionalTest::InnerModule")
      expect(FlossFunding.licensed).not_to include("TraditionalTest::InnerModule")
    end

    it "tracks libraries with unpaid silence license keys" do
      # Set up an unpaid silence license key
      stubbed_env("FLOSS_FUNDING_TRADITIONAL_TEST_INNER_MODULE" => FlossFunding::FREE_AS_IN_BEER) do
        # Include the Poke module
        stub_const("TraditionalTest::InnerModule", Module.new)
        TraditionalTest::InnerModule.send(:include, FlossFunding::Poke.new(__FILE__))

        # Check that the module was added to the licensed list
        expect(FlossFunding.licensed).to include("TraditionalTest::InnerModule")
        expect(FlossFunding.unlicensed).not_to include("TraditionalTest::InnerModule")
      end
    end
  end

  describe "multithreaded tracking" do
    it "correctly tracks libraries when included from multiple threads" do
      # Set up a valid license key for the first module
      valid_key = "161A84A3F7383B5BEA81BA1A0B71EA558D987012BE0A07087961F96AC72CF777"

      stubbed_env("FLOSS_FUNDING_TRADITIONAL_TEST_INNER_MODULE" => valid_key) do
        # Freeze time to August 2125
        Timecop.freeze(Time.new(2125, 8, 1)) do
          # Create two modules for testing
          stub_const("TraditionalTest::InnerModule", Module.new)
          stub_const("TraditionalTest::OtherModule", Module.new)

          # Create and start two threads
          thread1 = Thread.new do
            TraditionalTest::InnerModule.send(:include, FlossFunding::Poke.new(__FILE__))
          end

          thread2 = Thread.new do
            # No license key for the second module
            TraditionalTest::OtherModule.send(:include, FlossFunding::Poke.new(__FILE__))
          end

          # Wait for both threads to complete
          thread1.join
          thread2.join

          # Check that both modules were tracked correctly
          expect(FlossFunding.licensed).to include("TraditionalTest::InnerModule")
          expect(FlossFunding.unlicensed).to include("TraditionalTest::OtherModule")
        end
      end
    end
  end

  describe "END hook" do
    it "outputs the correct emoji for licensed and unlicensed libraries via real process", :check_output do
      ruby = RbConfig.ruby
      lib_dir = File.expand_path("../../lib", __dir__) # project/lib

      script = File.expand_path("../fixtures/end_hook_script.rb", __dir__)

      stdout, stderr, status = Open3.capture3(ruby, "-I", lib_dir, script, lib_dir)

      # Ensure the child process ran successfully
      expect(status.exitstatus).to eq(0), "Child process failed: #{stderr}\nSTDOUT: #{stdout}"

      # Validate actual at_exit output from the child process
      expect(stdout).to include("FlossFunding Summary:")
      expect(stdout).to include("Licensed libraries (1): ⭐️")
      expect(stdout).to include("Unlicensed libraries (1): 🫥")
    end
  end
end
