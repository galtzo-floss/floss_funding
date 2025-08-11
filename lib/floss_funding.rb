# frozen_string_literal: true

# std libs
require "openssl"
require "thread" # For Mutex

# external gems
require "month/serializer"
Month.include(Month::Serializer)

# Just the version from this gem
require "floss_funding/version"

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

  # Thread-safe access to activated and unactivated libraries
  # These track which modules/gems have included the Poke module
  # and whether they have valid activation keys or not
  # rubocop:disable ThreadSafety/MutableClassInstanceVariable
  @mutex = Mutex.new
  @activated = []   # List of libraries with valid activation
  @unactivated = [] # List of libraries without valid activation
  @configurations = {} # Hash to store configurations for each library
  @env_var_names = {} # Map of namespace => ENV var name used during setup
  @activation_occurrences = [] # Tracks every successful activation occurrence (may include duplicates per namespace)
  # rubocop:enable ThreadSafety/MutableClassInstanceVariable

  class << self
    # Provides access to the mutex for thread synchronization
    attr_reader :mutex

    # New name: activated (preferred)
    # @return [Array<String>]
    def activated
      mutex.synchronize { @activated.dup }
    end

    # New name: activated= (preferred)
    # @param value [Array<String>]
    def activated=(value)
      mutex.synchronize { @activated = value }
    end

    # New name: unactivated (preferred)
    # @return [Array<String>]
    def unactivated
      mutex.synchronize { @unactivated.dup }
    end

    # New name: unactivated= (preferred)
    # @param value [Array<String>]
    def unactivated=(value)
      mutex.synchronize { @unactivated = value }
    end

    # Thread-safely adds a library to the activated list
    # Ensures no duplicates are added
    # @param library [String] Namespace of the library to add
    def add_activated(library)
      mutex.synchronize { @activated << library unless @activated.include?(library) }
    end

    # Thread-safely adds a library to the unactivated list
    # Ensures no duplicates are added
    # @param library [String] Namespace of the library to add
    def add_unactivated(library)
      mutex.synchronize { @unactivated << library unless @unactivated.include?(library) }
    end

    # Thread-safe accessor for the configurations hash
    # Returns a duplicate to prevent external modification
    # @return [Hash] Hash of library configurations
    def configurations
      mutex.synchronize { @configurations.dup }
    end

    # Thread-safe getter for a specific library's configuration
    # @param library [String] Namespace of the library
    # @return [Hash, nil] Configuration for the library or nil if not found
    def configuration(library)
      mutex.synchronize do
        value = @configurations[library]
        value ? value.dup : nil
      end
    end

    # Thread-safe setter for a library's configuration
    # @param library [String] Namespace of the library
    # @param config [Hash] Configuration for the library
    def set_configuration(library, config)
      mutex.synchronize do
        existing = @configurations[library] || {}
        merged = {}
        # Ensure all known keys are arrays and merged
        keys = (existing.keys + config.keys).uniq
        keys.each do |k|
          merged[k] = []
          merged[k].concat(Array(existing[k])) if existing.key?(k)
          merged[k].concat(Array(config[k])) if config.key?(k)
          merged[k] = merged[k].compact.flatten.uniq
        end
        @configurations[library] = merged
      end
    end

    # Thread-safe setter for ENV var name used by a library
    # @param library [String]
    # @param env_var_name [String]
    def set_env_var_name(library, env_var_name)
      mutex.synchronize { @env_var_names[library] = env_var_name }
    end

    # Thread-safe getter for ENV var name used by a library
    # @param library [String]
    # @return [String, nil]
    def env_var_name_for(library)
      mutex.synchronize { @env_var_names[library] }
    end

    # Thread-safe getter for all ENV var names
    # @return [Hash{String=>String}]
    def env_var_names
      mutex.synchronize { @env_var_names.dup }
    end

    # Thread-safe getter for all activation occurrences (each successful activation event)
    # @return [Array<String>] list of namespaces for each activation occurrence
    def activation_occurrences
      mutex.synchronize { @activation_occurrences.dup }
    end

    # Record a single activation occurrence (may include duplicates per namespace)
    # @param namespace [String]
    def add_activation_occurrence(namespace)
      mutex.synchronize { @activation_occurrences << namespace }
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
require "floss_funding/poke"
# require "floss_funding/check" # Lazy loaded at runtime

# Dog Food
FlossFunding.send(:include, FlossFunding::Poke.new(__FILE__, :namespace => "FlossFunding"))

# :nocov:
# Add END hook to display summary and a consolidated blurb for usage without activation key
# This hook runs when the Ruby process terminates
at_exit {
  activated = FlossFunding.activated
  unactivated = FlossFunding.unactivated
  activated_count = activated.size
  unactivated_count = unactivated.size
  occurrences_count = FlossFunding.activation_occurrences.size

  # Compute how many distinct gem names are covered by funding.
  # Only consider namespaces that ended up ACTIVATED; unactivated are excluded by design.
  # Shared namespaces (e.g., final 10) will still contribute all gem names because configs merge per-namespace.
  configs = FlossFunding.configurations
  observed_namespaces = activated.uniq
  funded_gem_names = observed_namespaces.flat_map { |ns|
    cfg = configs[ns]
    cfg.is_a?(Hash) ? Array(cfg["gem_name"]) : []
  }.compact.uniq
  funded_gem_count = funded_gem_names.size

  # Summary section
  if activated_count > 0 || unactivated_count > 0
    stars = ("⭐️" * activated_count)
    mimes = ("🫥" * unactivated_count)
    summary_lines = []
    summary_lines << "\nFLOSS Funding Summary:"
    summary_lines << "Activated libraries (#{activated_count}): #{stars}" if activated_count > 0
    # Also show total successful inclusions (aka per-gem activations), which may exceed unique namespaces
    summary_lines << "Activated gems (#{occurrences_count})" if occurrences_count > 0
    # Show how many distinct gem names are covered by funding
    summary_lines << "Gems covered by funding (#{funded_gem_count})" if funded_gem_count > 0
    summary_lines << "Unactivated libraries (#{unactivated_count}): #{mimes}" if unactivated_count > 0
    summary = summary_lines.join("\n") + "\n\n"
    puts summary
  end

  # Emit a single, consolidated blurb for all unactivated namespaces
  if unactivated_count > 0
    # Gather data needed for each namespace
    configs = FlossFunding.configurations
    env_map = FlossFunding.env_var_names

    details = +""
    details << <<-HEADER
==============================================================
Unremunerated use of the following namespaces was detected:
    HEADER

    unactivated.each do |ns|
      config = configs[ns] || {}
      funding_url = Array(config["floss_funding_url"]).first || "https://floss-funding.dev"
      suggested_amount = Array(config["suggested_donation_amount"]).first || 5
      env_name = env_map[ns] || "FLOSS_FUNDING_#{ns.gsub(/[^A-Za-z0-9]+/, "_").upcase}"
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
      env_name = env_map[ns] || "FLOSS_FUNDING_#{ns.gsub(/[^A-Za-z0-9]+/, "_").upcase}"
      details << "  export #{env_name}=\"<your key>\"\n"
    end

    details << FlossFunding::FOOTER

    puts details
  end
}
# :nocov:
