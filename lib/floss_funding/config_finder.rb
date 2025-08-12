# frozen_string_literal: true

# When dropping support for Ruby < 2.2, refactor requires
# require_relative 'file_finder'

# This file is from RuboCop, with light edits for purpose.
# RuboCop is under the same MIT license.
#
# Copyright (c) 2012-23 Bozhidar Batsov
module FlossFunding
  # This class has methods related to finding a configuration path.
  # @api private
  class ConfigFinder
    DOTFILE = '.floss_funding.yml'
    XDG_CONFIG = 'config.yml'
    FLOSS_FUNDING_HOME = File.realpath(File.join(File.dirname(__FILE__), '..', '..'))
    DEFAULT_FILE = File.join(FLOSS_FUNDING_HOME, 'config', 'default.yml')

    class << self
      include FileFinder

      # The project root is global for a process because there can be only one root.
      # This is in contrast to library root, which is one-per library.
      attr_writer :project_root

      def find_config_path(target_dir)
        find_project_dotfile(target_dir) || find_user_dotfile || find_user_xdg_config ||
          DEFAULT_FILE
      end

      # Returns the path inferred as the root of the project. No file
      # searches will go past this directory.
      def project_root
        @project_root ||= find_project_root
      end

      private

      # Compute a project root starting from a given directory by looking for
      # common Bundler/gemspec indicators. This mirrors find_project_root but
      # anchors the search to the provided start_dir instead of Dir.pwd.
      # @param start_dir [String]
      # @return [String, nil] directory path of the discovered root
      def project_root_for(start_dir)
        root_indicator_file =
          find_file_upwards('Gemfile', start_dir) ||
          find_file_upwards('gems.rb', start_dir) ||
          find_file_upwards('*.gemspec', start_dir)
        return unless root_indicator_file

        dir = File.dirname(root_indicator_file)
        # Ignore the gem's own repository root when resolving a project root for
        # external/embedded consumers (e.g., test fixtures within this repo).
        return nil if dir == FLOSS_FUNDING_HOME

        dir
      end

      def find_project_root
        pwd = Dir.pwd
        root_indicator_file =
          find_last_file_upwards('Gemfile', pwd) ||
          find_last_file_upwards('gems.rb', pwd) ||
          find_last_file_upwards('*.gemspec', pwd)
        return unless root_indicator_file

        File.dirname(root_indicator_file)
      end

      def find_project_dotfile(target_dir)
        # Determine a project root relative to the target_dir. If none is found,
        # restrict the search to the starting directory to avoid accidentally
        # picking up unrelated ancestor configs (e.g., test fixture roots).
        relative_root = project_root_for(target_dir)
        # If no project root, allow searching up to the immediate parent directory only.
        stop_dir = relative_root || File.dirname(target_dir)
        find_file_upwards(DOTFILE, target_dir, stop_dir)
      end

      def find_user_dotfile
        return unless ENV.key?('HOME')

        file = File.join(Dir.home, DOTFILE)

        return file if File.exist?(file)
      end

      def find_user_xdg_config
        xdg_config_home = expand_path(ENV.fetch('XDG_CONFIG_HOME', '~/.config'))
        xdg_config = File.join(xdg_config_home, 'rubocop', XDG_CONFIG)

        return xdg_config if File.exist?(xdg_config)
      end

      def expand_path(path)
        File.expand_path(path)
      rescue ArgumentError
        # Could happen because HOME or ID could not be determined. Fall back on
        # using the path literally in that case.
        path
      end
    end
  end
end
