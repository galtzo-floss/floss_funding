# frozen_string_literal: true

require "ruby-progressbar"

module FlossFunding
  # Builds and renders an end-of-process summary without exposing any attributes.
  # All information is derived from global FlossFunding state to avoid tight coupling.
  class FinalSummary
    def initialize
      # Precompute everything once; print at the end.
      @namespaces = ::FlossFunding.all_namespaces
      @events = @namespaces.flat_map(&:activation_events)

      # Caches for repeated queries
      @activated_ns_names = pick_ns_names_with_state(::FlossFunding::STATES[:activated])
      @unactivated_ns_names = pick_ns_names_with_state(::FlossFunding::STATES[:unactivated])
      @invalid_ns_names = pick_ns_names_with_state(::FlossFunding::STATES[:invalid])

      @activated_libs = pick_unique_libs_with_state(::FlossFunding::STATES[:activated])
      @unactivated_libs = pick_unique_libs_with_state(::FlossFunding::STATES[:unactivated])
      @invalid_libs = pick_unique_libs_with_state(::FlossFunding::STATES[:invalid])

      @all_libs = unique_libraries(@events.map(&:library))

      render
    end

    private

    def pick_ns_names_with_state(state)
      @namespaces.select { |ns| ns.has_state?(state) }.map(&:name).uniq
    end

    def pick_unique_libs_with_state(state)
      libs = @events.select { |e| e.state == state }.map(&:library)
      unique_libraries(libs)
    end

    def unique_libraries(libs)
      # Library does not override ==, so uniq gives object identity uniqueness.
      Array(libs).compact.uniq
    end

    def render
      # 3. Choose a random namespace from unactivated + invalid and show info
      showcased_ns = random_unpaid_or_invalid_namespace

      lines = []
      if showcased_ns
        lines << "=============================================================="
        lines << "Unactivated/Invalid namespace spotlight:"
        lines << namespace_details_block(showcased_ns)
      end

      # 4. Render a summary of counts
      lines << "FLOSS Funding Summary:"
      lines << counts_line("activated", @activated_ns_names.size, @activated_libs.size)
      lines << counts_line("unactivated", @unactivated_ns_names.size, @unactivated_libs.size)
      if (@invalid_ns_names.size + @invalid_libs.size) > 0
        lines << counts_line("invalid", @invalid_ns_names.size, @invalid_libs.size)
      end

      puts lines.join("\n")

      # 5. Show a progressbar of activated libraries over total fingerprinted libraries
      total = @all_libs.size
      progressbar = ProgressBar.create(:title => "Activated Libraries", :total => total)
      @activated_libs.size.times { progressbar.increment }
      # Ensure we end with a newline after progress bar output
      puts ""
    rescue StandardError
      # Never allow an error here to affect process exit status — swallow safely.
    end

    def counts_line(label, namespaces_count, libraries_count)
      "#{label}: namespaces=#{namespaces_count} / libraries=#{libraries_count}"
    end
    
    def namespace_details_block(ns)
      name = ns.name
      env_name = ns.env_var_name
      config = ::FlossFunding.configurations[name]
      cfg = Array(config).first # configuration(s) were arrays; show first for brevity

      funding_url = begin
        Array(cfg && (cfg.respond_to?(:to_h) ? cfg.to_h["floss_funding_url"] : cfg["floss_funding_url"]))
      rescue StandardError
        []
      end
      funding_url = funding_url.first || "https://floss-funding.dev"

      suggested_amount = begin
        Array(cfg && (cfg.respond_to?(:to_h) ? cfg.to_h["suggested_donation_amount"] : cfg["suggested_donation_amount"]))
      rescue StandardError
        []
      end
      suggested_amount = suggested_amount.first || 5

      opt_out = "#{::FlossFunding::NOT_FINANCIALLY_SUPPORTING}-#{name}"

      libs = ns.activation_events.map(&:library).compact.uniq
      gem_names = libs.map(&:gem_name).compact.uniq

      details = []
      details << "- Namespace: #{name}"
      details << "  ENV Variable: #{env_name}"
      details << "  Libraries: #{gem_names.join(", ")}" unless gem_names.empty?
      details << "  Suggested donation amount: $#{suggested_amount}"
      details << "  Funding URL: #{funding_url}"
      details << "  Opt-out key: \"#{opt_out}\""
      details.join("\n")
    end

    def random_unpaid_or_invalid_namespace
      pool = @namespaces.select do |ns|
        ns.has_state?(::FlossFunding::STATES[:unactivated]) || ns.has_state?(::FlossFunding::STATES[:invalid])
      end
      return nil if pool.empty?
      pool[rand(pool.size)]
    end
  end
end
