# frozen_string_literal: true

require "pathname"
require "floss_funding/file_finder"

module FlossFunding
  # Discovers a library (producer/gem) root given an including file path.
  class LibraryRoot
    class << self
      include ::FlossFunding::FileFinder

      def cache
        @cache ||= {}
      end

      def reset_cache!
        @cache = {}
      end

      # Discover the root directory of a library by walking up from including_path
      # and looking for Gemfile, gems.rb, or any *.gemspec file, in a single ascent.
      # @param including_path [String]
      # @return [String, nil]
      def discover(including_path)
        start_dir = File.expand_path(File.dirname(including_path))
        return cache[start_dir] if cache.key?(start_dir)

        root = nil
        Pathname.new(start_dir).expand_path.ascend do |dir|
          dir_s = dir.to_s
          if File.exist?(File.join(dir_s, "Gemfile")) ||
             File.exist?(File.join(dir_s, "gems.rb")) ||
             !Dir.glob(File.join(dir_s, "*.gemspec")).empty?
            root = dir_s
            break
          end
        end

        cache[start_dir] = root
      end
    end
  end
end
