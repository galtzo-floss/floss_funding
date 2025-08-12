# frozen_string_literal: true

require 'floss_funding/config_finder'

module FlossFunding
  # Discovers and caches the single project root for the current process.
  # Project root is considered the consumer application's root.
  class ProjectRoot
    class << self
      # Returns the cached project root path, discovering it if necessary.
      # @return [String, nil]
      def path
        @path ||= discover
      end

      # Forces discovery of the project root using ConfigFinder logic.
      # @return [String, nil]
      def discover
        ::FlossFunding::ConfigFinder.project_root
      end

      # Allows resetting the cached project root (useful for tests).
      # @return [void]
      def reset!
        @path = nil
      end
    end
  end
end
