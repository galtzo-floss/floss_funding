# frozen_string_literal: true

# std libs
require "erb"
require "pathname"
require "yaml"
require "openssl"
require "set"
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
  # Debug toggle controlled by ENV; set true when ENV['FLOSS_FUNDING_DEBUG'] case-insensitively equals "true".
  DEBUG = ENV.fetch("FLOSS_FUNDING_DEBUG", "").casecmp("true") == 0

  # Minimum required keys for a valid .floss_funding.yml file
  # Used to validate presence when integrating without :wedge mode
  REQUIRED_YAML_KEYS = %w[library_name funding_uri].freeze

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
    :activated => "activated",
    :unactivated => "unactivated",
    :invalid => "invalid",
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

  # How Time Affects Activation Keys
  #
  # It doesn't matter if the class / module gets reloaded,
  # because activation keys are valid into the future, effectively forever.
  # If the system time somehow gets set into the past, the key will be invalid.
  # Since invalid keys are inert, nothing breaks.
  # A warning would be printed about the invalid key,
  # which may be a gentle way to discover that your system time is broken.
  #
  # Time source for month arithmetic; overridable for tests.
  # @return [Time]
  @loaded_at = Time.now.freeze

  # Current Month index for time-based key validity
  # @return [Integer]
  @loaded_month = Month.new(@loaded_at.year, @loaded_at.month).to_i

  # Number of valid words based on the current month window
  # @return [Integer]
  @num_valid_words_for_month = @loaded_month - ::FlossFunding::START_MONTH

  class << self
    # Provides access to the mutex for thread synchronization
    attr_reader :mutex

    # Read the deterministic time source
    #
    # @see @loaded_at
    #
    # @param value [Time]
    # @return [Time]
    attr_reader :loaded_at

    # Read the serialized month (Integer) in which the runtime was loaded
    #
    # @see @loaded_at
    #
    # @param value [Integer]
    # @return [Integer]
    attr_reader :loaded_month

    # Read the number of valid words for the month in which the runtime was loaded
    #
    # @see @loaded_at
    #
    # @param value [Integer]
    # @return [Integer]
    attr_reader :num_valid_words_for_month

    # Debug logging helper. Only outputs when FlossFunding::DEBUG is true.
    # Accepts either a message (or multiple args joined by space) or a block
    # for lazy construction of the message.
    # @param args [Array<Object>] message parts to join with space
    # @yieldreturn [String] optional block returning the message
    # @return [void]
    def log(*args)
      return unless ::FlossFunding::DEBUG
      msg = if block_given?
        yield
      else
        args.map(&:to_s).join(" ")
      end
      # Ensure a string and a newline
      puts(msg)
    rescue StandardError
      # Never fail the caller due to logging issues
      nil
    end

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
      mutex.synchronize do
        ns_obj = namespace
        # Append in place to reduce allocations and avoid extra mutex churn
        ns_obj.activation_events << event
        @namespaces[namespace.name] = ns_obj
      end
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
        names = []
        @namespaces.each_value do |nobj|
          names << nobj.name if nobj.has_state?(STATES[:activated])
        end
        names
      end
    end

    # Unactivated namespaces are those that have at least one :unactivated event
    # @return [Array<String>]
    def unactivated_namespace_names
      mutex.synchronize do
        names = []
        @namespaces.each_value do |nobj|
          names << nobj.name if nobj.has_state?(STATES[:unactivated])
        end
        names
      end
    end

    # Invalid namespaces are those that have at least one :invalid event
    # @return [Array<String>]
    def invalid_namespace_names
      mutex.synchronize do
        names = []
        @namespaces.each_value do |nobj|
          names << nobj.name if nobj.has_state?(STATES[:invalid])
        end
        names
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

    # Reads the first N lines from the base words file to validate paid activation keys.
    #
    # @param num_valid_words [Integer] number of words to read from the word list
    # @return [Array<String>] the first N words; empty when N is nil or zero
    # Reads base words used to validate paid activation keys.
    # When called without an argument, uses the current month window to
    # determine how many words are valid.
    #
    # @param num_valid_words [Integer, nil]
    # @return [Array<String>]
    def base_words(num_valid_words = nil)
      n = num_valid_words.nil? ? num_valid_words_for_month : num_valid_words
      return [] if n.nil? || n.zero?

      # Load all words once
      all = (@base_words_all ||= begin
        words = []
        begin
          File.foreach(::FlossFunding::BASE_WORDS_PATH) { |line| words << line.chomp }
        rescue StandardError
          words = []
        end
        words.freeze
      end)

      all[0, n] || []
    end

    # Check whether a plaintext activation base word is currently valid
    # @param plain_text [String]
    # @return [Boolean]
    def check_activation(plain_text)
      n = ::FlossFunding.num_valid_words_for_month
      return false if n.nil? || n <= 0
      # Cache a Set for fast membership per current n
      sets = (@base_words_set_cache ||= {})
      set = sets[n]
      unless set
        set = Set.new(base_words(n))
        sets[n] = set
      end
      set.include?(plain_text)
    end

    # Emit a diagnostic message when an activation key is invalid
    # @param activation_key [String]
    # @param namespace [String]
    # @param env_var_name [String]
    # @return [void]
    def start_coughing(activation_key, namespace, env_var_name)
      return if ::FlossFunding::ContraIndications.at_exit_contraindicated?
      puts <<-COUGHING
==============================================================
COUGH, COUGH.
Ahem, it appears as though you tried to set an activation key
for #{namespace}, but it was invalid.

  Current (Invalid) Activation Key: #{activation_key}
  Namespace: #{namespace}
  ENV Variable: #{env_var_name}

Paid activation keys are 8 bytes, 64 hex characters, long.
Unpaid activation keys have varying lengths, depending on type and namespace.
Yours is #{activation_key.length} characters long, and doesn't match any paid or unpaid keys.

Please unset the current ENV variable #{env_var_name}, since it is invalid.

Then find the correct one, or get a new one @ https://floss-funding.dev and set it.

#{FlossFunding::FOOTER}
      COUGHING
    end

    # Emit the standard friendly funding message for unactivated usage
    # @param namespace [String]
    # @param env_var_name [String]
    # @param gem_name [String]
    # @return [void]
    def start_begging(namespace, env_var_name, gem_name)
      return if ::FlossFunding::ContraIndications.at_exit_contraindicated?
      puts %(FLOSS Funding: Activation key missing for #{gem_name} (#{namespace}). Set ENV["#{env_var_name}"] to your activation key; details will be shown at exit.)
    end

    def initiate_begging(event)
      library = event.library
      ns = library.namespace
      env_var_name = ::FlossFunding::UnderBar.env_variable_name(ns)
      gem_name = library.gem_name
      activation_key = event.activation_key

      case event.state
      when ::FlossFunding::STATES[:activated]
        nil
      when ::FlossFunding::STATES[:invalid]
        ::FlossFunding.start_coughing(activation_key, ns, env_var_name)
      else
        ::FlossFunding.start_begging(ns, env_var_name, gem_name)
      end
    end
  end
end

# Finally, the core of this gem
require "floss_funding/fingerprint"
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
require "floss_funding/final_summary"
# require "floss_funding/wedge" # Used independently, loaded discretely

# Dog Food
FlossFunding.send(
  :include,
  FlossFunding::Poke.new(
    __FILE__,
    :namespace => "FlossFunding",
    :silent => false,
    :wedge => true,
  ),
)

# :nocov:
# Add END hook to display a final summary. This hook runs when the Ruby process terminates.
at_exit do
  begin
    # 1. Preserve exit status by ensuring no exceptions bubble out of this block.
    # 2. Respect silence signal and short-circuit when contraindicated.
    next if FlossFunding::ContraIndications.at_exit_contraindicated?

    # 2B. Not silent: build and render the final summary.
    FlossFunding::FinalSummary.new
  rescue StandardError
    # 1. Never allow our errors to flip a successful exit into a failure.
    # Swallow all exceptions here.
  end
end
# :nocov:
