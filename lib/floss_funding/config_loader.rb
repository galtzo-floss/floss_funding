# frozen_string_literal: true

# Lightweight configuration loader facade adapted from RuboCop but trimmed
# down for FlossFunding's needs. Provides only the minimal API we require.

require 'yaml'
require 'floss_funding/config_finder'
require 'floss_funding/file_finder'

module FlossFunding
  class ConfigNotFoundError < ::FlossFunding::Error; end

  class ConfigLoader
    FLOSS_FUNDING_HOME = File.realpath(File.join(File.dirname(__FILE__), '..', '..'))
    DEFAULT_FILE = File.join(FLOSS_FUNDING_HOME, 'config', 'default.yml')

    class << self
      include ::FlossFunding::FileFinder

      def clear_options
        ::FlossFunding::FileFinder.root_level = nil
      end

      # Returns the path to the applicable config file for target_dir.
      def configuration_file_for(target_dir)
        ::FlossFunding::ConfigFinder.find_config_path(target_dir)
      end

      # Loads a YAML file and returns a Hash (empty if unreadable).
      def load_file(file, check: true)
        YAML.safe_load(File.read(file)) || {}
      rescue Errno::ENOENT
        raise ConfigNotFoundError, "Configuration file not found: #{file}"
      rescue StandardError
        {}
      end

      # Returns the default configuration Hash.
      def default_configuration
        load_file(DEFAULT_FILE)
      end
    end

    clear_options
  end
end
