# frozen_string_literal: true

require "yaml"

module FlossFunding
  # This module handles configuration loading from .floss_funding.yml files
  module Config
    CONFIG_FILE_NAME = ".floss_funding.yml"
    DEFAULT_CONFIG = {
      "suggested_donation_amount" => 5,
      "funding_url" => "https://floss-funding.dev",
    }.freeze

    class << self
      # Loads configuration from .floss_funding.yml file
      # @param base [Module] The module that included FlossFunding::Poke
      # @return [Hash] Configuration hash with default values merged
      def load_config(base)
        config_file = find_config_file(base)
        raw_config = config_file ? load_yaml_file(config_file) : {}

        # Backward compatibility: if funding_url isn't set, but legacy keys are,
        # synthesize funding_url from donation_url (preferred) or subscription_url.
        normalized = raw_config.dup
        unless normalized.key?("funding_url")
          if normalized["donation_url"] && !normalized["donation_url"].to_s.empty?
            normalized["funding_url"] = normalized["donation_url"]
          elsif normalized["subscription_url"] && !normalized["subscription_url"].to_s.empty?
            normalized["funding_url"] = normalized["subscription_url"]
          end
        end

        # Merge with defaults; drop legacy keys but keep any other user-specified keys
        merged = DEFAULT_CONFIG.merge(normalized)
        merged.delete("donation_url")
        merged.delete("subscription_url")
        merged
      end

      private

      # Finds the configuration file by looking in the gem's root directory
      # @param base [Module] The module that included FlossFunding::Poke
      # @return [String, nil] Path to the config file or nil if not found
      def find_config_file(base)
        # Try to find the gem's root directory
        gem_root = find_gem_root(base)
        return unless gem_root

        config_path = File.join(gem_root, CONFIG_FILE_NAME)
        File.exist?(config_path) ? config_path : nil
      end

      # Attempts to find the root directory of the gem that included FlossFunding::Poke
      # @param base [Module] The module that included FlossFunding::Poke
      # @return [String, nil] Path to the gem's root directory or nil if not found
      def find_gem_root(base)
        # Try to find the file that defines the module
        begin
          # Get the file that defines the module
          module_file = base.name.split("::").map(&:downcase).join("/") + ".rb"

          # Try to find the file in the load path
          $LOAD_PATH.each do |path|
            full_path = File.join(path, module_file)
            if File.exist?(full_path)
              # Go up until we find the gem's root (where .gemspec might be)
              current_dir = File.dirname(full_path)
              while current_dir != "/"
                if Dir.glob(File.join(current_dir, "*.gemspec")).any? ||
                    File.exist?(File.join(current_dir, "Gemfile"))
                  return current_dir
                end
                current_dir = File.dirname(current_dir)
              end
            end
          end
        rescue
          # If there's any error, just return nil
          nil
        end

        nil
      end

      # Loads and parses a YAML file
      # @param file_path [String] Path to the YAML file
      # @return [Hash] Parsed YAML content or empty hash if parsing fails
      def load_yaml_file(file_path)
        begin
          YAML.load_file(file_path) || {}
        rescue
          # If there's any error loading the file, return an empty hash
          {}
        end
      end
    end
  end
end
