# frozen_string_literal: true

require "pathname"
require "floss_funding/file_finder"

module FlossFunding
  # Discovers a library (producer/gem) root given an including file path.
  class LibraryRoot
    class << self
      include ::FlossFunding::FileFinder

      # Discover the root directory of a library by walking up from including_path
      # and looking for Gemfile, gems.rb, or a *.gemspec file.
      # @param including_path [String]
      # @return [String, nil]
      def discover(including_path)
        start_dir = File.expand_path(File.dirname(including_path))
        candidates = [
          find_file_upwards("Gemfile", start_dir),
          find_file_upwards("gems.rb", start_dir),
          find_file_upwards("*.gemspec", start_dir),
        ].compact
        File.dirname(candidates.first) unless candidates.empty?
      end
    end
  end
end
