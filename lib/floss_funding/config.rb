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

    class << self
      # Determines whether any registered configuration requests silence.
      # Uses ::FlossFunding.configurations internally.
      # For each library's config, examines the "silent" key values. If any value
      # responds to :call, it will be invoked (with no args) and the truthiness of
      # its return value is used. Otherwise, the value's own truthiness is used.
      # Returns true if any library requires silence; false otherwise.
      #
      # @return [Boolean]
      def silence_requested?
        configurations = ::FlossFunding.configurations
        configurations.any? do |_library, cfg|
          values = Array(cfg["silent"]) # may be nil/array/scalar
          values.any? do |v|
            begin
              v.respond_to?(:call) ? !!v.call : !!v
            rescue StandardError
              # If callable raises, treat as not silencing
              false
            end
          end
        end
      end

      private

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
