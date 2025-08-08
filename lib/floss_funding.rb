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
  class Error < StandardError; end

  FREE_AS_IN_BEER = "Free-as-in-beer"
  BUSINESS_IS_NOT_GOOD_YET = "Business-is-not-good-yet"
  NOT_FINANCIALLY_SUPPORTING = "Not-financially-supporting"
  START_MONTH = Month.new(2025, 7).to_i # Don't change this, not ever!
  BASE_WORDS_PATH = File.expand_path("../../base.txt", __FILE__)
  EIGHT_BYTES = 64
  HEX_LICENSE_RULE = /\A[0-9a-fA-F]{#{EIGHT_BYTES}}\z/

  # Thread-safe access to licensed and unlicensed libraries
  # These track which modules/gems have included the Poke module
  # and whether they have valid licenses or not
  @mutex = Mutex.new
  @licensed = []   # List of libraries with valid licenses
  @unlicensed = [] # List of libraries without valid licenses
  @configurations = {} # Hash to store configurations for each library

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

# Add END hook to display emoji based on licensed/unlicensed counts
# This hook runs when the Ruby process terminates
# It displays:
# - A row of ⭐️ emoji (one for each licensed library)
# - A row of 🫥 emoji (one for each unlicensed library)
# This provides visual feedback about which libraries are properly licensed
at_exit {
  licensed_count = FlossFunding.licensed.size
  unlicensed_count = FlossFunding.unlicensed.size

  if licensed_count > 0 || unlicensed_count > 0
    puts "\nFlossFunding Summary:"
    puts "Licensed libraries (#{licensed_count}): #{"⭐️" * licensed_count}" if licensed_count > 0
    puts "Unlicensed libraries (#{unlicensed_count}): #{"🫥" * unlicensed_count}" if unlicensed_count > 0
    puts ""
  end
}
