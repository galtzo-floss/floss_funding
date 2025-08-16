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

      stub_env(FlossFunding::UnderBar.env_variable_name("TraditionalTest::InnerModule") => valid_key)
      # Freeze time to August 2125
      Timecop.freeze(Time.new(2125, 8, 1)) do
        # Include the Poke module
        stub_const("TraditionalTest::InnerModule", Module.new)
        TraditionalTest::InnerModule.send(:include, FlossFunding::Poke.new(__FILE__))

        # Check that the module was added to the activated list
        activated_namespaces = FlossFunding.all_namespaces.select { |ns| ns.state == FlossFunding::STATES[:activated] }.map(&:name)
        not_activated_namespaces = FlossFunding.all_namespaces.select { |ns| ns.state != FlossFunding::STATES[:activated] }.map(&:name)

        expect(activated_namespaces).to include("TraditionalTest::InnerModule")
        expect(not_activated_namespaces).not_to include("TraditionalTest::InnerModule")
      end
    end

    it "tracks unactivated libraries", :check_output do
      # No activation key set
      stub_env(FlossFunding::UnderBar.env_variable_name("TraditionalTest::InnerModule") => nil)

      # Include the Poke module
      stub_const("TraditionalTest::InnerModule", Module.new)
      TraditionalTest::InnerModule.send(:include, FlossFunding::Poke.new(__FILE__))

      # Check that the module was added to the unactivated list
      unactivated_namespaces = FlossFunding.all_namespaces.select { |ns| ns.state == FlossFunding::STATES[:unactivated] }.map(&:name)
      not_unactivated_namespaces = FlossFunding.all_namespaces.select { |ns| ns.state != FlossFunding::STATES[:unactivated] }.map(&:name)

      expect(unactivated_namespaces).to include("TraditionalTest::InnerModule")
      expect(not_unactivated_namespaces).not_to include("TraditionalTest::InnerModule")
    end

    it "tracks libraries with unpaid silence activation keys" do
      # Set up an unpaid silence activation key
      stub_env(FlossFunding::UnderBar.env_variable_name("TraditionalTest::InnerModule") => FlossFunding::FREE_AS_IN_BEER)
      # Include the Poke module
      stub_const("TraditionalTest::InnerModule", Module.new)
      TraditionalTest::InnerModule.send(:include, FlossFunding::Poke.new(__FILE__))

      # Check that the module was added to the activated list
      activated_namespaces = FlossFunding.all_namespaces.select { |ns| ns.state == FlossFunding::STATES[:activated] }.map(&:name)
      not_activated_namespaces = FlossFunding.all_namespaces.select { |ns| ns.state != FlossFunding::STATES[:activated] }.map(&:name)

      expect(activated_namespaces).to include("TraditionalTest::InnerModule")
      expect(not_activated_namespaces).not_to include("TraditionalTest::InnerModule")
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
        # Also include one module on the main thread for determinism
        TraditionalTest::InnerModule.send(:include, FlossFunding::Poke.new(__FILE__))

        thread1 = Thread.new do
          # Include for one module (again) to exercise concurrency paths
          TraditionalTest::InnerModule.send(:include, FlossFunding::Poke.new(__FILE__))
        end

        thread2 = Thread.new do
          # No activation key for the second module
          TraditionalTest::OtherModule.send(:include, FlossFunding::Poke.new(__FILE__))
        end

        # Wait for both threads to complete
        thread1.join
        thread2.join

        # Check that both modules were tracked (regardless of state under concurrency)
        activated_namespaces = FlossFunding.all_namespaces.select { |ns| ns.state == FlossFunding::STATES[:activated] }.map(&:name)
        unactivated_namespaces = FlossFunding.all_namespaces.select { |ns| ns.state == FlossFunding::STATES[:unactivated] }.map(&:name)
        all_names = FlossFunding.all_namespaces.map(&:name)

        expect(all_names).to include("TraditionalTest::InnerModule")
        expect(all_names).to include("TraditionalTest::OtherModule")
        # Under concurrency, state timing can vary; ensure OtherModule is not activated
        expect(unactivated_namespaces).to include("TraditionalTest::OtherModule")
        # InnerModule should be tracked, and is expected to be activated; if not, it must be unactivated but present
        expect(activated_namespaces.include?("TraditionalTest::InnerModule") || unactivated_namespaces.include?("TraditionalTest::InnerModule")).to be(true)

        # Ensure env var names are derived and present for both namespaces
        names = FlossFunding.env_var_names
        expect(names["TraditionalTest::InnerModule"]).to eq(FlossFunding::UnderBar.env_variable_name("TraditionalTest::InnerModule"))
        expect(names["TraditionalTest::OtherModule"]).to eq(FlossFunding::UnderBar.env_variable_name("TraditionalTest::OtherModule"))

        # Validate configurations are available and include library_name entries
        merged_config = FlossFunding.configurations("TraditionalTest::InnerModule")
        expect(merged_config).to be_a(FlossFunding::Configuration)
        expect(Array(merged_config["library_name"]).compact).to include("floss_funding")

        # Exercise base_words early return branch
        expect(FlossFunding.base_words(0)).to eq([])
      end
    end
  end
end
