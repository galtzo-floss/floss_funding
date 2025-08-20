# frozen_string_literal: true

# Lightweight configuration loader facade adapted from RuboCop but trimmed
# down for FlossFunding's needs. Provides only the minimal API we require.
#
# Copyright (c) 2012-23 Bozhidar Batsov

require "yaml"
require "floss_funding/config_finder"
require "floss_funding/file_finder"

module FlossFunding
  # Raised when a requested configuration file cannot be found on disk.
  # Intended to be caught by callers that need to distinguish between
  # "file missing" and other YAML parsing issues.
  # @see FlossFunding::ConfigLoader.load_file
  class ConfigNotFoundError < ::FlossFunding::Error; end

  # Lightweight configuration loader facade adapted from RuboCop but trimmed
  # down for FlossFunding's needs. Provides only the minimal API we require
  # to locate and load YAML configuration files for libraries using the
  # FlossFunding integration.
  class ConfigLoader
    # Absolute path to the root of the floss_funding project (the gem itself).
    # @return [String]
    FF_ROOT = File.realpath(File.join(File.dirname(__FILE__), "..", ".."))

    # Absolute path to the built-in default configuration YAML file.
    # @return [String]
    DEFAULT_FILE = File.join(FF_ROOT, "config", "default.yml")

    class << self
      include ::FlossFunding::FileFinder

      # Clear any memoized or process-level options in FileFinder that may
      # affect config discovery between runs (primarily a testing helper).
      # @return [void]
      def clear_options
        ::FlossFunding::FileFinder.root_level = nil
      end

      # Returns the path to the applicable config file for target_dir.
      # Delegates to ConfigFinder which performs the upward search.
      #
      # @param target_dir [String] directory to anchor the search from
      # @return [String, nil] absolute path to a .floss_funding.yml or nil if none found
      def configuration_file_for(target_dir)
        ::FlossFunding::ConfigFinder.find_config_path(target_dir)
      end

      # Loads a YAML file and returns a Hash. When the file is unreadable or
      # contains invalid YAML, returns an empty Hash. When the file is missing,
      # raises ConfigNotFoundError.
      #
      # @param file [String] absolute path to a YAML file
      # @param check [Boolean] reserved for future validations (currently unused)
      # @return [Hash]
      # @raise [FlossFunding::ConfigNotFoundError] when the file does not exist
      def load_file(file, check: true)
        YAML.safe_load(File.read(file)) || {}
      rescue Errno::ENOENT
        raise ConfigNotFoundError, "Configuration file not found: #{file}"
      rescue StandardError
        {}
      end

      # Returns the default configuration hash loaded from default.yml.
      # Values are raw as provided in YAML; downstream code will normalize
      # them as needed (e.g., wrapping scalars into arrays).
      # Memoized for the lifetime of the process; tests may clear via reset_caches!.
      # @return [Hash]
      def default_configuration
        @default_configuration ||= load_file(DEFAULT_FILE).freeze
      end

      # Testing hook to clear internal caches
      # @note Test shim: used by specs/benchmarks; no internal usage as of 2025-08-13.
      # @return [void]
      def reset_caches!
        @default_configuration = nil
      end
    end

    # Initialize FileFinder state for this process. Performed on file load.
    clear_options
  end
end
