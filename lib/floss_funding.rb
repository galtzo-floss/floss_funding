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

  # Unpaid license option intended for open-source and not-for-profit use.
  # @return [String]
  FREE_AS_IN_BEER = "Free-as-in-beer"

  # Unpaid license option acknowledging commercial use without payment.
  # @return [String]
  BUSINESS_IS_NOT_GOOD_YET = "Business-is-not-good-yet"

  # License option to explicitly opt out of funding prompts for a namespace.
  # @return [String]
  NOT_FINANCIALLY_SUPPORTING = "Not-financially-supporting"

  # First month index against which license words are validated.
  # Do not change once released as it invalidates license word lists.
  # @return [Integer]
  START_MONTH = Month.new(2025, 7).to_i # Don't change this, not ever!

  # Absolute path to the base words list used for paid license validation.
  # @return [String]
  BASE_WORDS_PATH = File.expand_path("../../base.txt", __FILE__)

  # Number of hex characters required for a paid license (64 = 256 bits).
  # @return [Integer]
  EIGHT_BYTES = 64

  # Format for a paid activation key (64 hex chars).
  # @return [Regexp]
  HEX_LICENSE_RULE = /\A[0-9a-fA-F]{#{EIGHT_BYTES}}\z/

  # Thread-safe access to licensed and unlicensed libraries
  # These track which modules/gems have included the Poke module
  # and whether they have valid licenses or not
  @mutex = Mutex.new
  @licensed = []   # List of libraries with valid licenses
  @unlicensed = [] # List of libraries without valid licenses
  @configurations = {} # Hash to store configurations for each library
  @env_var_names = {} # Map of namespace => ENV var name used during setup

  class << self
    # Provides access to the mutex for thread synchronization
    attr_reader :mutex

    # Thread-safe accessor for the licensed libraries list
    # Returns a duplicate to prevent external modification
    # @return [Array<String>] List of library namespaces with valid licenses
    def licensed
      mutex.synchronize { @licensed.dup }
    end

    # Thread-safe setter for the licensed libraries list
    # @param value [Array<String>] New list of licensed libraries
    def licensed=(value)
      mutex.synchronize { @licensed = value }
    end

    # Thread-safe accessor for the unlicensed libraries list
    # Returns a duplicate to prevent external modification
    # @return [Array<String>] List of library namespaces without valid licenses
    def unlicensed
      mutex.synchronize { @unlicensed.dup }
    end

    # Thread-safe setter for the unlicensed libraries list
    # @param value [Array<String>] New list of unlicensed libraries
    def unlicensed=(value)
      mutex.synchronize { @unlicensed = value }
    end

    # Thread-safely adds a library to the licensed list
    # Ensures no duplicates are added
    # @param library [String] Namespace of the library to add
    def add_licensed(library)
      mutex.synchronize { @licensed << library unless @licensed.include?(library) }
    end

    # Thread-safely adds a library to the unlicensed list
    # Ensures no duplicates are added
    # @param library [String] Namespace of the library to add
    def add_unlicensed(library)
      mutex.synchronize { @unlicensed << library unless @unlicensed.include?(library) }
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
      mutex.synchronize { @configurations[library]&.dup }
    end

    # Thread-safe setter for a library's configuration
    # @param library [String] Namespace of the library
    # @param config [Hash] Configuration for the library
    def set_configuration(library, config)
      mutex.synchronize { @configurations[library] = config }
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

    # Reads the first N lines from the base words file to validate paid licenses.
    #
    # @param num_valid_words [Integer] number of words to read from the word list
    # @return [Array<String>] the first N words; empty when N is nil or zero
    def base_words(num_valid_words)
      return [] if num_valid_words.nil? || num_valid_words.zero?
      File.open(::FlossFunding::BASE_WORDS_PATH, "r") do |file|
        lines = []
        num_valid_words.times { lines << file.gets.chomp }
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
# require "floss_funding/cli/gimlet" # Loaded by CLI only

# Add END hook to display summary and a consolidated blurb for unlicensed usage
# This hook runs when the Ruby process terminates
at_exit {
  licensed = FlossFunding.licensed
  unlicensed = FlossFunding.unlicensed
  licensed_count = licensed.size
  unlicensed_count = unlicensed.size

  if licensed_count > 0 || unlicensed_count > 0
    puts "\nFlossFunding Summary:"
    puts "Licensed libraries (#{licensed_count}): #{"⭐️" * licensed_count}" if licensed_count > 0
    puts "Unlicensed libraries (#{unlicensed_count}): #{"🫥" * unlicensed_count}" if unlicensed_count > 0
    puts ""
  end

  # Emit a single, consolidated blurb for all unlicensed namespaces
  if unlicensed_count > 0
    # Gather data needed for each namespace
    configs = FlossFunding.configurations
    env_map = FlossFunding.env_var_names

    puts "=============================================================="
    puts "Unremunerated use of the following namespaces was detected:"
    unlicensed.each do |ns|
      config = configs[ns] || {}
      funding_url = config["floss_funding_url"] || "https://floss-funding.dev"
      suggested_amount = config["suggested_donation_amount"] || 5
      env_name = env_map[ns] || "FLOSS_FUNDING_#{ns.gsub(/[^A-Za-z0-9]+/, '_').upcase}"
      opt_out = "#{::FlossFunding::NOT_FINANCIALLY_SUPPORTING}-#{ns}"
      puts "  - Namespace: #{ns}"
      puts "    ENV Variable: #{env_name}"
      puts "    Suggested donation amount: $#{suggested_amount}"
      puts "    Funding URL: #{funding_url}"
      puts "    Opt-out key: \"#{opt_out}\""
    end
    puts ""
    puts "FlossFunding relies on empathy, respect, honor, and annoyance of the most extreme mildness."
    puts "👉️ No network calls. 👉️ No tracking. 👉️ No oversight. 👉️ Minimal crypto hashing."
    puts ""
    puts "Options:"
    puts "  1. 🌐  Donate or sponsor at the funding URLs above, and affirm on your honor your donor or sponsor status."
    puts "     a. Receive ethically-sourced, buy-once, activation key for each namespace."
    puts "     b. Suggested donation amounts are listed above."
    puts ""
    puts "  2. 🪄  If open source, or not-for-profit, continue to use for free, with activation key: \"#{::FlossFunding::FREE_AS_IN_BEER}\"."
    puts ""
    puts "  3. 🏦  If commercial, continue to use for free, & feel a bit naughty, with activation key: \"#{::FlossFunding::BUSINESS_IS_NOT_GOOD_YET}\"."
    puts ""
    puts "  4. ✖️  Disable license checks using the per-namespace opt-out keys listed above."
    puts ""
    puts "Then, before loading the gems, set the ENV variables listed above to your chosen key."
    puts "Or in shell / dotenv / direnv, e.g.:"
    unlicensed.each do |ns|
      env_name = env_map[ns] || "FLOSS_FUNDING_#{ns.gsub(/[^A-Za-z0-9]+/, '_').upcase}"
      puts "  export #{env_name}=\"<your key>\""
    end
    puts ""
    puts "=============================================================="
    puts "- Please buy FLOSS licenses to support open source developers."
    puts "FlossFunding v#{::FlossFunding::Version::VERSION} is made with ❤️ in 🇺🇸 & 🇮🇩 by Galtzo FLOSS."
  end
}
