# frozen_string_literal: true

require "yaml"

module FlossFunding
  # Handles configuration loading from a .floss_funding.yml file located at the
  # root of the including project (heuristically discovered by walking upward
  # from the including file path until a Gemfile or *.gemspec is found).
  #
  # All APIs in this module require the including file path (e.g., __FILE__).
  # Legacy behaviors (like deducing from a Module) are intentionally unsupported.
  #
  # The loaded config is merged over DEFAULT_CONFIG, so any unspecified keys fall
  # back to defaults.
  module Config
    # The file name to look for in the project root.
    # @return [String]
    CONFIG_FILE_NAME = ".floss_funding.yml"

    # Default configuration values for FlossFunding prompting.
    # @return [Hash{String=>Object}]
    DEFAULT_CONFIG = {
      "suggested_donation_amount" => 5,
      "floss_funding_url" => "https://floss-funding.dev",
    }.freeze

    class << self
      # Loads configuration from .floss_funding.yml by walking up from the
      # provided including file path to discover the project root.
      #
      # @param including_path [String] the including file path (e.g., __FILE__)
      # @return [Hash{String=>Object}] configuration hash with defaults merged
      # @raise [::FlossFunding::Error] if including_path is not a String
      def load_config(including_path)
        unless including_path.is_a?(String)
          raise ::FlossFunding::Error, "including must be a String file path (e.g., __FILE__), got #{including_path.class}"
        end
        config_file = find_config_file(including_path)
        raw_config = config_file ? load_yaml_file(config_file) : {}

        # Merge with defaults, with constraints:
        # - Keys are Strings (not Symbols)
        # - Keys match names defined in DEFAULT_CONFIG
        # - Ignore all other keys to avoid accidental misconfiguration
        filtered = {}
        if raw_config.is_a?(Hash)
          raw_config.each do |k, v|
            next unless k.is_a?(String)
            filtered[k] = v if DEFAULT_CONFIG.key?(k)
          end
        end
        DEFAULT_CONFIG.merge(filtered)
      end

      private

      # Finds the configuration file by looking in the project's root directory.
      #
      # @param including_path [String] the including file path
      # @return [String, nil] absolute path to the config file or nil if not found
      def find_config_file(including_path)
        # Try to find the project's root directory
        project_root = find_project_root(including_path)
        return unless project_root

        config_path = File.join(project_root, CONFIG_FILE_NAME)
        File.exist?(config_path) ? config_path : nil
      end

      # Attempts to find the root directory of the project that included
      # FlossFunding::Poke by starting from the including file path and walking
      # up the directory tree until a Gemfile or *.gemspec is found.
      #
      # @param including_path [String] the including file path
      # @return [String, nil] the discovered project root directory or nil
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

      # Loads and parses a YAML file from disk.
      #
      # @param file_path [String] absolute path to the YAML file
      # @return [Hash] parsed YAML content or empty hash if parsing fails
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
