# frozen_string_literal: true

require "spec_helper"

RSpec.describe FlossFunding do
  describe ".env_var_names (derived)" do
    it "derives env var names from included namespaces and does not expose internals" do
      # Create two modules and include Poke to register namespaces
      stub_const("Alpha", Module.new)
      stub_const("Beta", Module.new)
      Alpha.const_set(:Lib, Module.new)
      Beta.const_set(:Lib, Module.new)
      Alpha::Lib.send(:include, FlossFunding::Poke.new(__FILE__))
      Beta::Lib.send(:include, FlossFunding::Poke.new(__FILE__))

      # Derived getter
      expected_alpha = FlossFunding::UnderBar.env_variable_name("Alpha::Lib")
      expected_beta = FlossFunding::UnderBar.env_variable_name("Beta::Lib")

      map = described_class.env_var_names
      expect(map).to include("Alpha::Lib" => expected_alpha, "Beta::Lib" => expected_beta)

      # Mutate the returned copy and ensure a fresh call is unaffected
      map["Alpha::Lib"] = "HACKED"
      fresh = described_class.env_var_names
      expect(fresh["Alpha::Lib"]).to eq(expected_alpha)
    end
  end
end
