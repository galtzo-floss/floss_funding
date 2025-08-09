# frozen_string_literal: true

require "yaml"

module FlossFunding
  # This module handles configuration loading from .floss_funding.yml files
  module Config
    CONFIG_FILE_NAME = ".floss_funding.yml"
    DEFAULT_CONFIG = {
      "suggested_donation_amount" => 5,
      "floss_funding_url" => "https://floss-funding.dev",
    }.freeze

    class << self
      # Loads configuration from .floss_funding.yml file
      # @param including_path [String] The including file path (required)
      # @return [Hash] Configuration hash with default values merged
      def load_config(including_path)
        unless including_path.is_a?(String)
          raise ::FlossFunding::Error, "including must be a String file path (e.g., __FILE__), got #{including_path.class}"
        end
        config_file = find_config_file(including_path)
        raw_config = config_file ? load_yaml_file(config_file) : {}

        # Merge with defaults; only support new-style keys
        DEFAULT_CONFIG.merge(raw_config)
      end

      private

      # Finds the configuration file by looking in the project's root directory
      # @param including_path [String] The including file path (required)
      # @return [String, nil] Path to the config file or nil if not found
      def find_config_file(including_path)
        # Try to find the project's root directory
        project_root = find_project_root(including_path)
        return unless project_root

        config_path = File.join(project_root, CONFIG_FILE_NAME)
        File.exist?(config_path) ? config_path : nil
      end

      # Attempts to find the root directory of the project that included FlossFunding::Poke
      # @param including_path [String] The including file path (required)
      # @return [String, nil] Path to the project's root directory or nil if not found
      def find_project_root(including_path)
        begin
          current_dir = File.dirname(File.expand_path(including_path))
          while current_dir && current_dir != "/"
            return current_dir if Dir.glob(File.join(current_dir, "*.gemspec")).any? || File.exist?(File.join(current_dir, "Gemfile"))
            current_dir = File.dirname(current_dir)
          end
        rescue
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
