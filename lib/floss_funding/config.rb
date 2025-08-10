# frozen_string_literal: true

require "yaml"
require "rubygems" # For Gem::Specification

module FlossFunding
  # Handles configuration loading from a .floss_funding.yml file located at the
  # root of the including project (heuristically discovered by walking upward
  # from the including file path until a Gemfile or *.gemspec is found).
  #
  # All APIs in this module require the including file path (e.g., `__FILE__`).
  #
  # The loaded config is merged over DEFAULT_CONFIG, so any unspecified keys fall
  # back to defaults.
  module Config
    # The file name to look for in the project root.
    # @return [String]
    CONFIG_FILE_NAME = ".floss_funding.yml"

    # Default configuration values for FlossFunding prompting.
    # Also includes slots for gemspec-derived attributes we track per gem.
    # @return [Hash{String=>Object}]
    DEFAULT_CONFIG = {
      "suggested_donation_amount" => [5],
      "floss_funding_url" => ["https://floss-funding.dev"],
      # Optional namespace override for when including without explicit namespace
      # When set (non-empty string), this will be used as the namespace instead of the including module's name
      "namespace" => [],
      # Gemspec-derived attributes (nil when unknown)
      "gem_name" => [],
      "homepage" => [],
      "authors" => [],
      "funding_uri" => [],
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

        # Discover project root (Gemfile or *.gemspec)
        project_root = find_project_root(including_path)

        # Load YAML config if present (respect test stubs of find_config_file)
        config_file = find_config_file(including_path)
        raw_config = config_file ? load_yaml_file(config_file) : {}

        # Strict filter: only allow known string keys, then normalize to arrays
        filtered = {}
        if raw_config.is_a?(Hash)
          raw_config.each do |k, v|
            next unless k.is_a?(String)
            next unless DEFAULT_CONFIG.key?(k)
            filtered[k] = normalize_to_array(v)
          end
        end

        # Load gemspec data for defaults if available
        gemspec_data = project_root ? read_gemspec_data(project_root) : {}
        # Prepare defaults from gemspec:
        # - Store all gemspec attributes into config slots, as arrays
        # - If floss_funding_url not set in YAML, default to gemspec funding_uri
        gemspec_defaults = {}
        if gemspec_data
          gemspec_defaults["gem_name"] = normalize_to_array(gemspec_data[:name]) if gemspec_data[:name]
          gemspec_defaults["homepage"] = normalize_to_array(gemspec_data[:homepage]) if gemspec_data[:homepage]
          gemspec_defaults["authors"] = normalize_to_array(gemspec_data[:authors]) if gemspec_data[:authors]
          gemspec_defaults["funding_uri"] = normalize_to_array(gemspec_data[:funding_uri]) if gemspec_data[:funding_uri]
          if gemspec_data[:funding_uri] && !filtered.key?("floss_funding_url")
            gemspec_defaults["floss_funding_url"] = normalize_to_array(gemspec_data[:funding_uri])
          end
        end

        # Merge precedence: DEFAULT < gemspec_defaults, with filtered_yaml overriding entirely when present
        merged = {}
        DEFAULT_CONFIG.keys.each do |key|
          if filtered.key?(key)
            # YAML-provided known string keys take full precedence (override defaults and gemspec values)
            merged[key] = Array(filtered[key]).compact.flatten.uniq
          else
            # Otherwise, start from defaults and enrich with gemspec-derived values when available
            merged[key] = []
            merged[key].concat(Array(DEFAULT_CONFIG[key]))
            merged[key].concat(Array(gemspec_defaults[key])) if gemspec_defaults.key?(key)
            merged[key] = merged[key].compact.flatten.uniq
          end
        end
        merged
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

      # Reads gemspec data from the first *.gemspec in project_root using
      # RubyGems API, and extracts fields of interest.
      # @param project_root [String]
      # @return [Hash] keys: :name, :homepage, :authors, :funding_uri
      def read_gemspec_data(project_root)
        gemspec_path = Dir.glob(File.join(project_root, "*.gemspec")).first
        return {} unless gemspec_path
        begin
          spec = Gem::Specification.load(gemspec_path)
          return {} unless spec
          metadata = spec.metadata || {}
          funding_uri = metadata["funding_uri"] || metadata[:funding_uri]
          {
            :name => spec.name,
            :homepage => spec.homepage,
            :authors => spec.authors,
            :funding_uri => funding_uri,
          }
        rescue StandardError
          {}
        end
      end

      # Normalize a value from YAML or gemspec to an array.
      # - nil => []
      # - array => same array
      # - scalar => [scalar]
      def normalize_to_array(value)
        return [] if value.nil?
        return value.compact if value.is_a?(Array)
        [value]
      end
    end
  end
end
