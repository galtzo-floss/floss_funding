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

  # Thread-safe access to arrays of ActivationEvent records, keyed by namespace
  # rubocop:disable ThreadSafety/MutableClassInstanceVariable
  @mutex = Mutex.new
  @activations = Hash.new do |h1, k1| # Hash to store an array of activation events for each namespace
    h1[k1] = []
  end
  # rubocop:enable ThreadSafety/MutableClassInstanceVariable

  class << self
    # Provides access to the mutex for thread synchronization
    attr_reader :mutex

    # Unique namespaces that have a valid activation key
    # @return [Array<String>]
    def activations
      mutex.synchronize { @activations.dup }
    end

    # @param value [Array<String>]
    def activations=(value)
      mutex.synchronize { @activations = value }
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
require "floss_funding/library"
require "floss_funding/activation_event"
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
at_exit {
  return if FlossFunding::Config.silence_requested?

  # Unique namespaces that have a valid activation key
  activated = FlossFunding.activated
  # Unique namespaces that do not have a valid activation key
  unactivated = FlossFunding.unactivated
  activated_count = activated.size
  unactivated_count = unactivated.size
  occurrences_count = FlossFunding.activation_occurrences.size

  # Compute how many distinct gem names are covered by funding.
  # Only consider namespaces that ended up ACTIVATED; unactivated are excluded by design.
  # Shared namespaces (e.g., final 10) will still contribute all gem names because configs merge per-namespace.
  configs = FlossFunding.configurations
  observed_namespaces = activated.uniq
  # These are the gem names that are covered by funding, regardless of whether they are ACTIVATED or not.
  funded_gem_names = observed_namespaces.flat_map { |ns|
    configs[ns]["gem_name"]
  }.compact.uniq
  funded_gem_count = funded_gem_names.size

  has_activated = activated_count > 0
  has_unactivated = unactivated_count > 0
  # Summary section
  if has_activated
    # # When there at least one activated namespace, show a progress bar and a summary.
    # print_progress_bar = -> (current, total, bar_length) {
    #   percentage = (current.to_f / total) * 100
    #   filled_length = (bar_length * percentage / 100).round
    #   bar = "=" * filled_length + "-" * (bar_length - filled_length)
    #   printf("\rProgress: [%s] %.1f%%", bar, percentage)
    #   STDOUT.flush # Ensure the output is immediately written to the terminal
    # }
    #
    # # Example usage:
    # total_items = 100
    # bar_length = 50
    # (0..total_items).each do |i|
    #   print_progress_bar.call(i, total_items, bar_length)
    #   sleep(0.05) # Simulate work being done
    # end
    # puts # Move to the next line after the progress bar is complete

    stars = ("⭐️" * activated_count)
    mimes = ("🫥" * unactivated_count)
    summary_lines = []
    summary_lines << "\nFLOSS Funding Summary:"
    summary_lines << "Activated namespaces (#{activated_count}): #{stars}" if activated_count > 0
    # Also show total successful inclusions (aka per-gem activations), which may exceed unique namespaces
    summary_lines << "Number of pokes (#{occurrences_count})" if occurrences_count > 0
    # Show how many distinct gem names are covered by funding
    summary_lines << "Gems covered by funding (#{funded_gem_count}): #{funded_gem_names.join(", ")}" if funded_gem_count > 0
    summary_lines << "Unactivated libraries (#{unactivated_count}): #{mimes}" if unactivated_count > 0
    summary = summary_lines.join("\n") + "\n\n"
    puts summary
  elsif has_unactivated
    # Emit a single, consolidated blurb showcasing a random unactivated namespace
    # Gather data needed for each namespace
    configs = FlossFunding.configurations
    env_map = FlossFunding.env_var_names

    details = +""
    details << <<-HEADER
==============================================================
Unremunerated use of the following namespaces was detected:
    HEADER

    unactivated.each do |ns|
      config = configs[ns]
      funding_url = Array(config["floss_funding_url"]).first || "https://floss-funding.dev"
      suggested_amount = Array(config["suggested_donation_amount"]).first || 5
      env_name = env_map[ns] || "#{FlossFunding::Constants::DEFAULT_PREFIX}#{ns.gsub(/[^A-Za-z0-9]+/, "_").upcase}"
      opt_out = "#{FlossFunding::NOT_FINANCIALLY_SUPPORTING}-#{ns}"
      details << <<-NS
  - Namespace: #{ns}
    ENV Variable: #{env_name}
    Suggested donation amount: $#{suggested_amount}
    Funding URL: #{funding_url}
    Opt-out key: "#{opt_out}"

      NS
    end

    details << <<-BODY
FLOSS Funding relies on empathy, respect, honor, and annoyance of the most extreme mildness.
👉️ No network calls. 👉️ No tracking. 👉️ No oversight. 👉️ Minimal crypto hashing.

Options:
  1. 🌐  Donate or sponsor at the funding URLs above, and affirm on your honor your donor or sponsor status.
     a. Receive ethically-sourced, buy-once, activation key for each namespace.
     b. Suggested donation amounts are listed above.

  2. 🪄  If open source, or not-for-profit, continue to use for free, with activation key: "#{FlossFunding::FREE_AS_IN_BEER}".

  3. 🏦  If commercial, continue to use for free, & feel a bit naughty, with activation key: "#{FlossFunding::BUSINESS_IS_NOT_GOOD_YET}".

  4. ✖️  Disable activation key checks using the per-namespace opt-out keys listed above.

Then, before loading the gems, set the ENV variables listed above to your chosen key.
Or in shell / dotenv / direnv, e.g.:
    BODY

    unactivated.each do |ns|
      env_name = env_map[ns] || "#{FlossFunding::Constants::DEFAULT_PREFIX}#{ns.gsub(/[^A-Za-z0-9]+/, "_").upcase}"
      details << "  export #{env_name}=\"<your key>\"\n"
    end

    details << FlossFunding::FOOTER

    puts details
  end
}
# :nocov:
