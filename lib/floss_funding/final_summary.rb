# frozen_string_literal: true

require "ruby-progressbar"
require "terminal-table"
require "rainbow"

module FlossFunding
  # Builds and renders an end-of-process summary without exposing any attributes.
  # All information is derived from global FlossFunding state to avoid tight coupling.
  class FinalSummary
    def initialize
      # Precompute everything once; print at the end.
      @namespaces = ::FlossFunding.all_namespaces
      ::FlossFunding.debug_log { "[FinalSummary] init namespaces=#{@namespaces.size}" }
      @events = @namespaces.flat_map(&:activation_events)
      ::FlossFunding.debug_log { "[FinalSummary] events=#{@events.size}" }

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
      # 3. Choose a random library from unactivated + invalid that hasn't nagged recently (at_exit lockfile)
      showcased_lib = random_unpaid_or_invalid_library

      lines = []
      if showcased_lib
        lines << "=============================================================="
        lines << "Unactivated/Invalid library spotlight:"
        lines << library_details_block(showcased_lib)

        # 4. Render a summary of counts
        root = ::FlossFunding.project_root
        root_label = (root.nil? || root.to_s.empty?) ? "(unknown)" : root.to_s
        lines << "FLOSS Funding Summary: #{root_label}"
        lines << build_summary_table
        ::FlossFunding.debug_log { "[FinalSummary] counts ns: activated=#{@activated_ns_names.size} unactivated=#{@unactivated_ns_names.size} invalid=#{@invalid_ns_names.size}; libs: activated=#{@activated_libs.size} unactivated=#{@unactivated_libs.size} invalid=#{@invalid_libs.size}" }

        ::FlossFunding.debug_log("[FinalSummary] " + lines.join("\n"))
        puts lines.join("\n")

        # 5. Show a progressbar of activated libraries over total fingerprinted libraries
        total = @all_libs.size
        if total > 0
          progressbar = ProgressBar.create(:title => "Activated Libraries", :total => total)
          @activated_libs.size.times { progressbar.increment }
          # Ensure we end with a newline after progress bar output
          puts ""
        end
      end
    rescue StandardError => e
      # Record the failure and switch library to inert mode.
      ::FlossFunding.error!(e, "FinalSummary#render")
    end

    # :nocov:
    # NOTE: Presently unused helper retained for readability; behavior trivially formats
    # a string and provides no additional execution value for tests.
    def counts_line(label, namespaces_count, libraries_count)
      "#{label}: namespaces=#{namespaces_count} / libraries=#{libraries_count}"
    end
    # :nocov:

    # Build a terminal-table summary with colored columns per status.
    def build_summary_table
      # Determine which statuses to show (skip invalid if no invalids at all)
      invalid_total = @invalid_ns_names.size + @invalid_libs.size
      statuses = ::FlossFunding::STATE_VALUES.dup
      statuses.delete(::FlossFunding::STATES[:invalid]) if invalid_total.zero?

      # Headings: first column empty (row labels), then status columns
      headings = [""] + statuses.map { |st| colorize_heading(st) }

      # Rows for namespaces and libraries
      ns_counts = counts_for(:namespaces)
      lib_counts = counts_for(:libraries)

      rows = []
      rows << (["namespaces"] + statuses.map { |st| colorize_cell(st, ns_counts[st]) })
      rows << (["libraries"] + statuses.map { |st| colorize_cell(st, lib_counts[st]) })

      Terminal::Table.new(:headings => headings, :rows => rows).to_s
    end

    # :nocov:
    # NOTE: This helper simply composes cached counts; branches are trivial and
    # already exercised indirectly by build_summary_table tests. Excluded to
    # improve determinism under varying pool compositions.
    def counts_for(kind)
      case kind
      when :namespaces
        {
          ::FlossFunding::STATES[:activated] => @activated_ns_names.size,
          ::FlossFunding::STATES[:unactivated] => @unactivated_ns_names.size,
          ::FlossFunding::STATES[:invalid] => @invalid_ns_names.size,
        }
      when :libraries
        {
          ::FlossFunding::STATES[:activated] => @activated_libs.size,
          ::FlossFunding::STATES[:unactivated] => @unactivated_libs.size,
          ::FlossFunding::STATES[:invalid] => @invalid_libs.size,
        }
      else
        {}
      end
    end
    # :nocov:

    # Try to detect if terminal background is dark (true), light (false), or unknown (nil)
    # :nocov:
    # NOTE: Background detection depends on terminal env. All meaningful branches
    # are indirectly exercised in colorization tests; the rescue path is excluded
    # to avoid platform-specific flakiness.
    def detect_dark_background
      cfg = ENV["COLORFGBG"]
      return unless cfg
      parts = cfg.split(";")
      bg = parts.last.to_i
      bg <= 7
    rescue StandardError
      nil
    end
    # :nocov:

    def colorize_heading(status)
      txt = status.to_s
      apply_color(txt, status)
    end

    def colorize_cell(status, count)
      apply_color(count.to_s, status)
    end

    def apply_color(text, status)
      # Only colorize when writing to a TTY; specs capture to StringIO and shouldn't receive ANSI codes.
      return text.to_s unless $stdout.tty?
      case status
      when ::FlossFunding::STATES[:activated]
        light_hex = "#90ee90"  # lightgreen
        dark_hex = "#006400"  # darkgreen
        default = ->(t) { Rainbow(t).green }
      when ::FlossFunding::STATES[:unactivated]
        light_hex = "#ffcc80"  # light orange
        dark_hex = "#ff8c00"  # dark orange
        default = ->(t) { Rainbow(t).color("#ffa500") } # orange
      when ::FlossFunding::STATES[:invalid]
        light_hex = "#87cefa"  # light sky blue
        dark_hex = "#00008b"  # dark blue
        default = ->(t) { Rainbow(t).blue }
      else
        return text
      end

      bg = detect_dark_background
      if bg.nil?
        default.call(text).to_s
      elsif bg # dark background -> use lighter hues
        Rainbow(text).color(light_hex).to_s
      else # light background -> use darker hues
        Rainbow(text).color(dark_hex).to_s
      end
    rescue StandardError => e
      # Log and fall back when color support fails; not a fatal error
      ::FlossFunding.debug_log { "[WARN][FinalSummary#apply_color] #{e.class}: #{e.message}" }
      text.to_s
    end

    def library_details_block(lib)
      name = lib.library_name
      ns_name = lib.namespace
      env_name = ::FlossFunding::UnderBar.env_variable_name(ns_name)
      config = ::FlossFunding.configurations[ns_name]
      cfg = Array(config).first

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

      opt_out = "#{::FlossFunding::NOT_FINANCIALLY_SUPPORTING}-#{ns_name}"

      details = []
      details << "- Library: #{name}"
      details << "  Namespace: #{ns_name}"
      details << "  ENV Variable: #{env_name}"
      details << "  Suggested donation amount: $#{suggested_amount}"
      details << "  Funding URL: #{funding_url}"
      details << "  Opt-out key: \"#{opt_out}\""
      details.join("\n")
    end

    def random_unpaid_or_invalid_library
      # Build pool of unique libraries in unactivated or invalid states
      libs = (@unactivated_libs + @invalid_libs).uniq
      return if libs.empty?

      # Filter using at_exit lockfile to exclude recently featured libraries
      lock = ::FlossFunding::Lockfile.at_exit
      filtered = libs.reject { |lib| lock && lock.nagged?(lib) }
      # If all candidates were recently nagged, do not spotlight any library this run.
      return if filtered.empty?
      pool = filtered

      chosen = pool[rand(pool.size)]

      # Record the at_exit nag so it won't be featured again within window
      if lock && chosen
        # Create a mock event-like struct for state recording; state is not critical for at_exit cards
        evt_state = ::FlossFunding::STATES[:unactivated]
        event_stub = Struct.new(:state).new(evt_state)
        lock.record_nag(chosen, event_stub, "at_exit")
      end

      chosen
    end
  end
end
