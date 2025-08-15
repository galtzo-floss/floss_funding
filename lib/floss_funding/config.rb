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
    class << self
      # Expose project root discovery to allow tests and callers to stub or
      # override it. Delegates to ConfigFinder.
      # @return [String, nil]
      def find_project_root
        ::FlossFunding::ConfigFinder.project_root
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
