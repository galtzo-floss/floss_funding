# frozen_string_literal: true

# Bulk injector: tries to include FlossFunding::Poke into many loaded gems.
#
# Usage (intended for diagnostics/bench testing in large apps):
#   FlossFunding::Wedge.wedge!
#
# Behavior:
# - Enumerates loaded gem specifications via Bundler (fallback to Gem).
# - Guesses Ruby namespace constants from gem names (handles dashes/underscores).
# - For each constant that exists and is a Module, performs `include FlossFunding::Poke.new(<path>)`.
# - Returns a summary Hash of attempts and successes for observability.
module FlossFunding
  class Wedge
    class << self
      # Perform the wedge across all currently loaded specs.
      # @return [Hash] summary with keys :tried, :injected, :details
      def wedge!
        results = {:tried => 0, :injected => 0, :details => []}

        loaded_specs.each do |spec|
          next unless valid_spec?(spec)
          next if spec.name == "floss_funding" # avoid self

          candidates = namespace_candidates_for(spec.name)
          injected_into = []

          candidates.each do |ns|
            mod = safe_const_resolve(ns)
            next unless mod.is_a?(Module)

            begin
              mod.send(:include, ::FlossFunding::Poke.new(spec.loaded_from || guess_including_path(spec)))
              injected_into << ns
            rescue StandardError
              # Swallow and continue; this is best-effort to probe many libs
            end
          end

          results[:tried] += 1
          results[:injected] += injected_into.size.positive? ? 1 : 0
          results[:details] << {:gem => spec.name, :injected_into => injected_into}
        end

        results
      end

      # Exposed for specs: source of loaded Gem::Specification objects
      def loaded_specs
        if defined?(::Bundler) && ::Bundler.respond_to?(:rubygems) && ::Bundler.rubygems.respond_to?(:loaded_specs)
          specs = ::Bundler.rubygems.loaded_specs
          specs = specs.values if specs.respond_to?(:values)
          Array(specs)
        else
          specs = ::Gem.loaded_specs
          specs = specs.values if specs.respond_to?(:values)
          Array(specs)
        end
      rescue StandardError
        []
      end

      # Turn a gem name into several candidate Ruby namespace strings
      # Examples:
      #  "google-cloud-storage" => [
      #    "Google::Cloud::Storage", "Google::Cloud", "Google",
      #    "GoogleCloudStorage"
      #  ]
      #  "alpha_beta" => ["AlphaBeta", "Alpha", "Alpha::Beta"]
      def namespace_candidates_for(gem_name)
        return [] if gem_name.nil? || gem_name.empty?

        dash_parts = gem_name.split("-")
        # Build CamelCase per dash part, where each part may contain underscores
        camel_parts = dash_parts.map { |p| camelize(p) }

        candidates = []
        # Most likely: top-level module per dash part
        if camel_parts.size > 1
          # Add full nested path, then its prefixes (e.g., Google::Cloud, Google)
          nested = camel_parts.join("::")
          candidates << nested
          (camel_parts.size - 1).downto(1) do |i|
            candidates << camel_parts[0, i].join("::")
          end
        end

        # Also attempt the fully collapsed CamelCase name
        candidates << camel_parts.join

        candidates.uniq
      end

      # Safe resolve of a constant path like "Foo::Bar" without raising
      def safe_const_resolve(path)
        return if path.nil? || path.empty?
        parts = path.split("::")
        obj = Object
        parts.each do |name|
          return nil unless begin
            obj.const_defined?(name, false)
          rescue
            false
          end || begin
            Object.const_defined?(name)
          rescue
            false
          end
          obj = begin
            obj.const_get(name)
          rescue
            (return nil)
          end
        end
        obj
      rescue StandardError
        nil
      end

      private

      def valid_spec?(spec)
        spec && spec.respond_to?(:name) && spec.name.is_a?(String) && !spec.name.empty?
      end

      # Try to provide a reasonable including_path when spec.loaded_from is nil
      def guess_including_path(spec)
        if spec.respond_to?(:full_gem_path) && spec.full_gem_path
          gemspec = Dir.glob(File.join(spec.full_gem_path, "*.gemspec")).first
          return gemspec if gemspec
        end
        __FILE__
      end

      # Camelize a gem name segment that may contain underscores
      #  "alpha_beta" => "AlphaBeta"
      def camelize(segment)
        segment.to_s.split("_").map { |s| s[0] ? s[0].upcase + s[1..-1].to_s : "" }.join
      end
    end
  end
end
