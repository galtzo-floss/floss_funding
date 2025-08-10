# frozen_string_literal: true

require "spec_helper"

RSpec.describe FlossFunding do
  describe ".env_var_name_for and .env_var_names" do
    it "returns the env var name previously set for a namespace and does not expose internals" do
      # Set two values
      described_class.set_env_var_name("Alpha::Lib", "ALPHA_LIB_KEY")
      described_class.set_env_var_name("Beta::Lib", "BETA_LIB_KEY")

      # Direct getter
      expect(described_class.env_var_name_for("Alpha::Lib")).to eq("ALPHA_LIB_KEY")
      expect(described_class.env_var_name_for("Beta::Lib")).to eq("BETA_LIB_KEY")

      # Returns a duplicate copy for safety
      map_copy = described_class.env_var_names
      expect(map_copy).to include("Alpha::Lib" => "ALPHA_LIB_KEY", "Beta::Lib" => "BETA_LIB_KEY")

      # Mutate the returned copy and ensure internals are not changed
      map_copy["Alpha::Lib"] = "HACKED"
      expect(described_class.env_var_name_for("Alpha::Lib")).to eq("ALPHA_LIB_KEY")
    end
  end
end
