# frozen_string_literal: true

# external gems
require "terminal-table"
require "floss_funding/terminal_helpers"

# this gem
require "floss_funding"

# Bulk injector: tries to include FlossFunding::Poke into many loaded gems.
#
# Usage (intended for diagnostics/bench testing in large apps):
#   FlossFunding::Wedge.wedge!
#
# Behavior:
# - Enumerates loaded gem specifications via Gem.loaded_specs.
# - Guesses Ruby namespace constants from gem names (handles dashes/underscores).
# - For each constant that exists and is a Module, performs `include FlossFunding::Poke.new(<path>, wedge: true)`.
# - Returns a summary Hash of attempts and successes for observability.
module FlossFunding
  class Wedge
    # When in dangerous mode will attempt to require gems that are "loaded specs".
    # This could be extremely dangerous, because some gems are destructive on load.
    # Fortunately this entire wedge file is not loaded at all by the floss_funding gem.
    # Wedge must be loaded explicitly; preferably in a clean testing environment.
    maybe_dangerous = ENV.fetch("FLOSS_FUNDING_WEDGE_DANGEROUS", "0") == "1"
    DANGEROUS =
      if maybe_dangerous
        if DEBUG
          maybe_dangerous
        else
          warn("Unable to use DANGEROUS mode because DEBUG=false.")
          false
        end
      else
        false
      end

    class << self
      # Perform the wedge across all currently loaded specs.
      # @return [Hash] summary with keys :tried, :injected, :details
      def wedge!
        ::FlossFunding.debug_log { "[Wedge] Starting wedge! DEBUG=#{::FlossFunding::DEBUG}" }
        results = {:tried => 0, :injected => 0, :details => []}

        specs = loaded_specs
        ::FlossFunding.debug_log { "[Wedge] Loaded specs count=#{specs.length}" }

        specs.each do |spec|
          unless valid_spec?(spec)
            ::FlossFunding.debug_log { "[Wedge] Skipping invalid spec=#{spec.inspect}" }
            next
          end
          if spec.name == "floss_funding"
            ::FlossFunding.debug_log { "[Wedge] Skipping self gem: #{spec.name}" }
            next
          end

          ::FlossFunding.debug_log { "[Wedge] Processing gem=#{spec.name}" }
          candidates = namespace_candidates_for(spec.name)
          ::FlossFunding.debug_log { "[Wedge] Candidates for #{spec.name}: #{candidates.inspect}" }
          injected_into = []

          # Dangerous effort: try to require the gem before resolving constants
          attempt_require_for_spec(spec, candidates) if DANGEROUS

          candidates.each do |ns|
            ::FlossFunding.debug_log { "[Wedge] Resolving constant path=#{ns} for gem=#{spec.name}" }
            mod = safe_const_resolve(ns)
            unless mod.is_a?(Module)
              ::FlossFunding.debug_log { "[Wedge] Not a Module or missing: #{ns} => #{mod.inspect}" }
              next
            end

            begin
              inc_path = spec.loaded_from || guess_including_path(spec)
              ::FlossFunding.debug_log { "[Wedge] Including Poke into #{ns} with path=#{inc_path.inspect}" }
              mod.send(:include, ::FlossFunding::Poke.new(inc_path, :wedge => true))
              injected_into << ns
              ::FlossFunding.debug_log { "[Wedge] Included successfully into #{ns}" }
            rescue StandardError => e
              # :nocov:
              ::FlossFunding.debug_log { "[Wedge] Include failed for #{ns}: #{e.class}: #{e.message}" }
              # Swallow and continue; this is best-effort to probe many libs
              # :nocov:
            end
          end

          results[:tried] += 1
          results[:injected] += injected_into.size.positive? ? 1 : 0
          details = {:gem => spec.name, :injected_into => injected_into}
          results[:details] << details
          ::FlossFunding.debug_log { "[Wedge] Result for #{spec.name}: #{details.inspect}" }
        end

        if DEBUG
          puts "[Wedge] Finished wedge!\n#{results.inspect}"
        else
          puts "[Wedge] Finished wedge!\n#{render_summary_table(results)}"
        end
        results
      end

      # Exposed for specs: source of loaded Gem::Specification objects
      def loaded_specs
        # Only use Gem.loaded_specs.
        # It is pointless to try using Bundler's version because all it does is call Gem.loaded_specs.
        specs, strategy =
          begin
            [::Gem.loaded_specs, "Gem.loaded_specs"]
          rescue StandardError => e
            ::FlossFunding.debug_log { "[Wedge] Gem.loaded_specs failed: #{e.class}: #{e.message}" }
            [[], "(error)"]
          end

        ::FlossFunding.debug_log { "[Wedge] Using #{strategy}" }
        specs = specs.values if specs.respond_to?(:values)
        arr = Array(specs)
        ::FlossFunding.debug_log { "[Wedge] Loaded specs: count=#{arr.length}" }
        arr
      rescue StandardError => e
        ::FlossFunding.debug_log { "[Wedge] loaded_specs failed: #{e.class}: #{e.message}" }
        []
      end

      # Turn a gem name into several candidate Ruby namespace strings
      # Examples:
      #  "google-cloud-storage" => [
      #    "Google::Cloud::Storage", "Google::Cloud", "Google",
      #    "GoogleCloudStorage"
      #  ]
      #  "alpha_beta" => ["AlphaBeta", "Alpha", "Alpha::Beta"]
      def namespace_candidates_for(library_name)
        ::FlossFunding.debug_log { "[Wedge] namespace_candidates_for input=#{library_name.inspect}" }
        return [] if library_name.nil? || library_name.empty?

        dash_parts = library_name.split("-")
        # Build CamelCase per dash part, where each part may contain underscores
        camel_parts = dash_parts.map { |p| camelize(p) }
        ::FlossFunding.debug_log { "[Wedge] camel_parts=#{camel_parts.inspect} from dash_parts=#{dash_parts.inspect}" }

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

        uniq = candidates.uniq
        ::FlossFunding.debug_log { "[Wedge] namespace_candidates_for output=#{uniq.inspect}" }
        uniq
      end

      # Safe resolve of a constant path like "Foo::Bar" without raising
      def safe_const_resolve(path)
        ::FlossFunding.debug_log { "[Wedge] safe_const_resolve path=#{path.inspect}" }
        return if path.nil? || path.empty?
        parts = path.split("::")
        obj = Object
        parts.each do |name|
          # :nocov:
          exists = begin
            obj.const_defined?(name, false)
          rescue
            false
          end || begin
            Object.const_defined?(name)
          rescue
            false
          end
          # :nocov:
          ::FlossFunding.debug_log { "[Wedge]   checking part=#{name.inspect} exists=#{exists} in obj=#{obj}" }
          return nil unless exists
          obj = begin
            obj.const_get(name)
          rescue
            # :nocov:
            ::FlossFunding.debug_log { "[Wedge]   const_get failed for #{name.inspect}" }
            # :nocov:
            (return nil)
          end
        end
        ::FlossFunding.debug_log { "[Wedge] safe_const_resolve resolved=#{obj.inspect}" }
        obj
      rescue StandardError => e
        # :nocov:
        ::FlossFunding.debug_log { "[Wedge] safe_const_resolve error: #{e.class}: #{e.message}" }
        nil
        # :nocov:
      end

      private

      # Render a human-friendly tabular summary of wedge results
      # One row per gem, with the namespaces into which Poke was included
      # Uses terminal-table; falls back to a simple inspect string on failure.
      def render_summary_table(results)
        details = Array(results[:details])
        # Exclude gems that failed to be injected into from the table rows
        rows = details.each_with_object([]) do |d, acc|
          injected_arr = Array(d[:injected_into])
          next if injected_arr.empty?
          library_name = d[:gem].to_s
          injected = injected_arr.join(", ")
          acc << [library_name, injected]
        end

        title = "[Wedge] Summary: tried=#{results[:tried]} injected=#{results[:injected]}"
        begin
          table = Terminal::Table.new(:title => title, :headings => ["Gem", "Injected Into"], :rows => rows)
          ::FlossFunding::Terminal.apply_width!(table)
          table.to_s
        rescue StandardError => e
          # Any terminal-table issues (missing constant, width errors, etc.): fallback to filtered list
          ::FlossFunding.debug_log { "[Wedge] render_summary_table terminal-table failed: #{e.class}: #{e.message}" }
          lines = [title]
          if rows.empty?
            lines << "(no injections)"
          else
            rows.each do |(gem_name, injected_into)|
              lines << "  #{gem_name}: #{injected_into}"
            end
          end
          lines.join("\n")
        end
      rescue StandardError => e
        ::FlossFunding.debug_log { "[Wedge] render_summary_table error: #{e.class}: #{e.message}" }
        "[Wedge] Summary: #{results.inspect}"
      end

      def valid_spec?(spec)
        ok = spec && spec.respond_to?(:name) && spec.name.is_a?(String) && !spec.name.empty?
        ::FlossFunding.debug_log { "[Wedge] valid_spec? #{spec.inspect} => #{ok}" }
        ok
      end

      # Try to provide a reasonable including_path when spec.loaded_from is nil
      def guess_including_path(spec)
        ::FlossFunding.debug_log { "[Wedge] guess_including_path for #{spec.inspect}" }
        if spec.respond_to?(:full_gem_path) && spec.full_gem_path
          gemspec = Dir.glob(File.join(spec.full_gem_path, "*.gemspec")).first
          ::FlossFunding.debug_log { "[Wedge] guess_including_path found gemspec=#{gemspec.inspect}" }
          return gemspec if gemspec
        end
        ::FlossFunding.debug_log { "[Wedge] guess_including_path defaulting to __FILE__=#{__FILE__}" }
        __FILE__
      end

      # Try to require a gem based on its spec and namespace candidates
      def attempt_require_for_spec(spec, candidates)
        name = spec.respond_to?(:name) ? spec.name.to_s : ""
        reqs = []
        reqs << name unless name.empty?
        reqs << name.tr("-", "/") unless name.empty?
        reqs << name.tr("-", "_") unless name.empty?

        # Derive require paths from constant candidates
        Array(candidates).each do |ns|
          next unless ns.is_a?(String) && !ns.empty?
          path = ns.gsub("::", "/").gsub(/([A-Z])/) { |m| m.downcase }
          reqs << path
        end

        reqs = reqs.uniq
        ::FlossFunding.debug_log { "[Wedge] attempt_require_for_spec gem=#{name} reqs=#{reqs.inspect}" }
        reqs.each do |r|
          begin
            ::FlossFunding.debug_log { "[Wedge]   require '#{r}' ..." }
            res = require r
            ::FlossFunding.debug_log { "[Wedge]   require '#{r}' => #{res.inspect}" }
          rescue LoadError, StandardError => e
            ::FlossFunding.debug_log { "[Wedge]   require '#{r}' failed: #{e.class}: #{e.message}" }
            # ignore; best-effort
          end
        end
      end

      # Camelize a gem name segment that may contain underscores
      #  "alpha_beta" => "AlphaBeta"
      def camelize(segment)
        res = segment.to_s.split("_").map { |s| s[0] ? s[0].upcase + s[1..-1].to_s : "" }.join
        ::FlossFunding.debug_log { "[Wedge] camelize #{segment.inspect} => #{res.inspect}" }
        res
      end
    end
  end
end
