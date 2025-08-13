# frozen_string_literal: true

# std libs
require 'erb'
require 'pathname'
require 'yaml'
require "openssl"
require "thread" # For Mutex

# external gems
require "month/serializer"
Month.include(Month::Serializer)

# Just the version from this gem
require "floss_funding/version"

# Load runtime control switch constants separately for easier test isolation
require "floss_funding/constants"

# Now declare some constants
module FlossFunding
  # Base error class for all FlossFunding-specific failures.
  class Error < StandardError; end

  # Unpaid activation option intended for open-source and not-for-profit use.
  # @return [String]
  FREE_AS_IN_BEER = "Free-as-in-beer"

  # Unpaid activation option acknowledging commercial use without payment.
  # @return [String]
  BUSINESS_IS_NOT_GOOD_YET = "Business-is-not-good-yet"

  # Activation option to explicitly opt out of funding prompts for a namespace.
  # @return [String]
  NOT_FINANCIALLY_SUPPORTING = "Not-financially-supporting"

  STATES = {
    :activated => 'activated',
    :unactivated => 'unactivated',
    :invalid => 'invalid',
  }.freeze

  # The default state is unknown / unactivated until proven otherwise.
  DEFAULT_STATE = STATES[:unactivated]

  # First month index against which base words are validated.
  # Do not change once released as it would invalidate existing activation keys.
  # @return [Integer]
  START_MONTH = Month.new(2025, 7).to_i # Don't change this, not ever!

  # Absolute path to the base words list used for paid activation validation.
  # @return [String]
  BASE_WORDS_PATH = File.expand_path("../../base.txt", __FILE__)

  # Number of hex characters required for a paid activation key (64 = 256 bits).
  # @return [Integer]
  EIGHT_BYTES = 64

  # Format for a paid activation key (64 hex chars).
  # @return [Regexp]
  HEX_LICENSE_RULE = /\A[0-9a-fA-F]{#{EIGHT_BYTES}}\z/

  # Footer text appended to messages shown to users when activation is missing
  # or invalid. Includes gem version and attribution.
  # @return [String]
  FOOTER = <<-FOOTER
=====================================================================================
- Please buy FLOSS "peace-of-mind" activation keys to support open source developers.
floss_funding v#{::FlossFunding::Version::VERSION} is made with ❤️ in 🇺🇸 & 🇮🇩 by Galtzo FLOSS (galtzo.com)
  FOOTER

  # rubocop:disable ThreadSafety/MutableClassInstanceVariable
  # Thread-safe access to Namespace records keyed by namespace string
  @mutex = Mutex.new
  # Hash to store a Namespace object per namespace string
  @namespaces = {}
  # Global silenced switch, defaults to the ENV-controlled constant
  @silenced = ::FlossFunding::Constants::SILENT
  # rubocop:enable ThreadSafety/MutableClassInstanceVariable

  class << self
    # Provides access to the mutex for thread synchronization
    attr_reader :mutex

    # Accessor for namespaces hash: keys are namespace strings, values are Namespace objects
    # @return [Hash[String, Array<::FlossFunding::Namespace>]]
    def namespaces
      mutex.synchronize { @namespaces.dup }
    end

    # Replace the namespaces hash (expects Hash[String, Array<::FlossFunding::Namespace>])
    def namespaces=(value)
      mutex.synchronize { @namespaces = value }
    end

    # Global silenced flag accessor (boolean)
    # @return [Boolean]
    def silenced
      mutex.synchronize { @silenced }
    end

    # Set the global silenced flag
    # @param value [Boolean]
    # @return [void]
    def silenced=(value)
      mutex.synchronize { @silenced = !!value }
    end

    def add_or_update_namespace_with_event(namespace, event)
      ::FlossFunding.namespaces = (
        ::FlossFunding.namespaces.tap do |spaces|
          ns_obj = namespace
          ns_obj.activation_events = ns_obj.activation_events + [event]
          spaces[namespace.name] = ns_obj
        end
      )
    end

    # All namespaces that have any activation events recorded
    # Returns array of Namespace objects
    # @return [Array<::FlossFunding::Namespace>]
    def all_namespaces
      mutex.synchronize { @namespaces.values.flatten.dup }
    end

    # All namespace names (strings)
    # @return [Array<String>]
    def all_namespace_names
      mutex.synchronize { @namespaces.keys.dup }
    end

    # Activated namespaces are those that have at least one :activated event
    # @return [Array<String>]
    def activated_namespace_names
      mutex.synchronize do
        @namespaces.values.select {|nobj| nobj.has_state?(STATES[:activated]) }.map(&:name)
      end
    end

    # Unactivated namespaces are those that have at least one :unactivated event
    # @return [Array<String>]
    def unactivated_namespace_names
      mutex.synchronize do
        @namespaces.values.select {|nobj| nobj.has_state?(STATES[:unactivated]) }.map(&:name)
      end
    end


    # Invalid namespaces are those that have at least one :invalid event
    # @return [Array<String>]
    def invalid_namespace_names
      mutex.synchronize do
        @namespaces.values.select {|nobj| nobj.has_state?(STATES[:invalid]) }.map(&:name)
      end
    end

    # Configuration storage and helpers (derived from namespaces and activation events)
    # When namespace is nil, returns a Hash mapping namespace String => Array<FlossFunding::Configuration>.
    # When namespace is provided, returns FlossFunding::Configuration for that namespace (or nil if not found).
    def configurations(namespace = nil)
      mutex.synchronize do
        if namespace
          nobj = @namespaces[namespace]
          nobj ? nobj.merged_config : nil
        else
          @namespaces.each_with_object({}) do |(ns, nobj), acc|
            acc[ns] = nobj.configs
          end
        end
      end
    end

    def configuration(namespace)
      configurations(namespace)
    end

    # ENV var name mapping helpers (derived from namespaces)
    # Returns a Hash mapping namespace String => ENV variable name String
    def env_var_names
      mutex.synchronize do
        @namespaces.transform_values { |nobj| nobj.env_var_name }
      end
    end

    # Return an array of namespace strings for each activation event occurrence (pokes)
    # e.g., ["Ns1", "Ns1", "Ns2"] if Ns1 had 2 events and Ns2 had 1
    # @return [Array<String>]
    def activation_occurrences
      mutex.synchronize do
        @namespaces.flat_map { |ns, nobj| nobj.activation_events.map { ns } }
      end
    end

    # Reads the first N lines from the base words file to validate paid activation keys.
    #
    # @param num_valid_words [Integer] number of words to read from the word list
    # @return [Array<String>] the first N words; empty when N is nil or zero
    def base_words(num_valid_words)
      return [] if num_valid_words.nil? || num_valid_words.zero?

      File.open(::FlossFunding::BASE_WORDS_PATH, "r") do |file|
        lines = []
        num_valid_words.times do
          line = file.gets
          break if line.nil?
          lines << line.chomp
        end
        lines
      end
    end
  end
end

# Finally, the core of this gem
require "floss_funding/under_bar"
require "floss_funding/config"
require "floss_funding/file_finder"
require "floss_funding/config_finder" # depends on FileFinder
require "floss_funding/config_loader" # depends on ConfigFinder
require "floss_funding/project_root"
require "floss_funding/library_root"
require "floss_funding/library"
require "floss_funding/namespace"
require "floss_funding/activation_event"
require "floss_funding/contra_indications"
require "floss_funding/inclusion"
require "floss_funding/poke"
# require "floss_funding/check" # Lazy loaded at runtime

# Dog Food
FlossFunding.send(
  :include,
  FlossFunding::Poke.new(
    __FILE__,
    :namespace => "FlossFunding",
    :silent => false,
  ),
)

# :nocov:
# Add END hook to display a summary and a consolidated blurb for usage without activation key
# This hook runs when the Ruby process terminates
# at_exit {
#   # Unique namespaces that have a valid activation key
#   activated = FlossFunding.activated_namespace_names
#   # Unique namespaces that do not have a valid activation key
#   unactivated = FlossFunding.unactivated_namespace_names
#   activated_count = activated.size
#   unactivated_count = unactivated.size
#   occurrences_count = FlossFunding.activation_occurrences.size
#
#   # Compute how many distinct gem names are covered by funding.
#   # Only consider namespaces that ended up ACTIVATED; unactivated are excluded by design.
#   # Shared namespaces (e.g., final 10) will still contribute all gem names because configs merge per-namespace.
#   configs = FlossFunding.configurations
#   observed_namespaces = activated.uniq
#   # These are the gem names that are covered by funding, regardless of whether they are ACTIVATED or not.
#   funded_gem_names = observed_namespaces.flat_map { |ns|
#     configs[ns]["gem_name"]
#   }.compact.uniq
#   funded_gem_count = funded_gem_names.size
#
#   has_activated = activated_count > 0
#   has_unactivated = unactivated_count > 0
#   # Summary section
#   if has_activated
#     # # When there at least one activated namespace, show a progress bar and a summary.
#     # print_progress_bar = -> (current, total, bar_length) {
#     #   percentage = (current.to_f / total) * 100
#     #   filled_length = (bar_length * percentage / 100).round
#     #   bar = "=" * filled_length + "-" * (bar_length - filled_length)
#     #   printf("\rProgress: [%s] %.1f%%", bar, percentage)
#     #   STDOUT.flush # Ensure the output is immediately written to the terminal
#     # }
#     #
#     # # Example usage:
#     # total_items = 100
#     # bar_length = 50
#     # (0..total_items).each do |i|
#     #   print_progress_bar.call(i, total_items, bar_length)
#     #   sleep(0.05) # Simulate work being done
#     # end
#     # puts # Move to the next line after the progress bar is complete
#
#     stars = ("⭐️" * activated_count)
#     mimes = ("🫥" * unactivated_count)
#     summary_lines = []
#     summary_lines << "\nFLOSS Funding Summary:"
#     summary_lines << "Activated libraries (#{activated_count}): #{stars}" if activated_count > 0
#     # Also show total successful inclusions (aka per-gem activations), which may exceed unique namespaces
#     summary_lines << "Number of pokes (#{occurrences_count})" if occurrences_count > 0
#     # Show how many distinct gem names are covered by funding
#     summary_lines << "Gems covered by funding (#{funded_gem_count}): #{funded_gem_names.join(", ")}" if funded_gem_count > 0
#     summary_lines << "Unactivated libraries (#{unactivated_count}): #{mimes}" if unactivated_count > 0
#     summary = summary_lines.join("\n") + "\n\n"
#     puts summary
#   elsif has_unactivated
#     # Emit a single, consolidated blurb showcasing a random unactivated namespace
#     # Gather data needed for each namespace
#     configs = FlossFunding.configurations
#     env_map = FlossFunding.env_var_names
#
#     details = +""
#     details << <<-HEADER
# ==============================================================
# Unremunerated use of the following namespaces was detected:
#     HEADER
#
#     unactivated.each do |ns|
#       config = configs[ns]
#       funding_url = Array(config["floss_funding_url"]).first || "https://floss-funding.dev"
#       suggested_amount = Array(config["suggested_donation_amount"]).first || 5
#       env_name = env_map[ns] || "#{FlossFunding::Constants::DEFAULT_PREFIX}#{ns.gsub(/[^A-Za-z0-9]+/, "_").upcase}"
#       opt_out = "#{FlossFunding::NOT_FINANCIALLY_SUPPORTING}-#{ns}"
#       details << <<-NS
#   - Namespace: #{ns}
#     ENV Variable: #{env_name}
#     Suggested donation amount: $#{suggested_amount}
#     Funding URL: #{funding_url}
#     Opt-out key: "#{opt_out}"
#
#       NS
#     end
#
#     details << <<-BODY
# FLOSS Funding relies on empathy, respect, honor, and annoyance of the most extreme mildness.
# 👉️ No network calls. 👉️ No tracking. 👉️ No oversight. 👉️ Minimal crypto hashing.
#
# Options:
#   1. 🌐  Donate or sponsor at the funding URLs above, and affirm on your honor your donor or sponsor status.
#      a. Receive ethically-sourced, buy-once, activation key for each namespace.
#      b. Suggested donation amounts are listed above.
#
#   2. 🪄  If open source, or not-for-profit, continue to use for free, with activation key: "#{FlossFunding::FREE_AS_IN_BEER}".
#
#   3. 🏦  If commercial, continue to use for free, & feel a bit naughty, with activation key: "#{FlossFunding::BUSINESS_IS_NOT_GOOD_YET}".
#
#   4. ✖️  Disable activation key checks using the per-namespace opt-out keys listed above.
#
# Then, before loading the gems, set the ENV variables listed above to your chosen key.
# Or in shell / dotenv / direnv, e.g.:
#     BODY
#
#     unactivated.each do |ns|
#       env_name = env_map[ns] || "#{FlossFunding::Constants::DEFAULT_PREFIX}#{ns.gsub(/[^A-Za-z0-9]+/, "_").upcase}"
#       details << "  export #{env_name}=\"<your key>\"\n"
#     end
#
#     details << FlossFunding::FOOTER
#
#     puts details
#   end
# }
# :nocov:
