# frozen_string_literal: true

# When dropping support for Ruby < 2.2, refactor requires
# require 'pathname'

# This file is from RuboCop, with light edits for purpose.
# RuboCop is under the same MIT license.
#
# Copyright (c) 2012-23 Bozhidar Batsov
module FlossFunding
  # Common methods for finding files.
  # @api private
  module FileFinder
    # Set the artificial root level used to stop upward traversal when searching.
    #
    # @param level [String, nil] Absolute directory path or nil to clear
    # @return [void]
    def self.root_level=(level)
      @root_level = level
    end

    # Check whether the given path has reached the configured root level or stop_dir.
    #
    # @param path [String, Pathname] The directory being checked during ascent
    # @param stop_dir [String, nil] Optional hard stop directory when no root_level is set
    # @return [Boolean] true if traversal should stop at this path
    def self.root_level?(path, stop_dir)
      (@root_level || stop_dir) == path.to_s
    end

    # Find the first occurrence of a file walking upward from a starting directory.
    #
    # @param filename [String] The basename or glob pattern to match (e.g., "Gemfile", "*.gemspec")
    # @param start_dir [String] Absolute or relative directory to start from
    # @param stop_dir [String, nil] Optional directory at which to stop searching
    # @return [String, nil] Absolute path to the first matching file, or nil if none found
    def find_file_upwards(filename, start_dir, stop_dir = nil)
      traverse_files_upwards(filename, start_dir, stop_dir) do |file|
        # minimize iteration for performance
        return file if file
      end
    end

    # Find the last occurrence of a file while walking upward from a starting directory.
    # Useful for selecting the nearest ancestor config file when multiple are present.
    #
    # @param filename [String] The basename or glob pattern to match (e.g., "Gemfile", "*.gemspec")
    # @param start_dir [String] Absolute or relative directory to start from
    # @param stop_dir [String, nil] Optional directory at which to stop searching
    # @return [String, nil] Absolute path to the last matching file, or nil if none found
    def find_last_file_upwards(filename, start_dir, stop_dir = nil)
      last_file = nil
      traverse_files_upwards(filename, start_dir, stop_dir) { |file| last_file = file }
      last_file
    end

    private

    def traverse_files_upwards(filename, start_dir, stop_dir)
      Pathname.new(start_dir).expand_path.ascend do |dir|
        file = dir + filename
        # Only consider regular files, not directories or other filesystem entries.
        yield(file.to_s) if file.file?

        break if FileFinder.root_level?(dir, stop_dir)
      end
    end
  end
end
