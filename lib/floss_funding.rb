# frozen_string_literal: true

# std libs
require "erb"
require "pathname"
require "yaml"
require "openssl"
require "set"
require "thread" # For Mutex
require "fileutils"

# external gems
require "month/serializer"
Month.include(Month::Serializer)

# Just the version from this gem
require "floss_funding/version"

# Load runtime control switch constants separately for easier test isolation
require "floss_funding/constants"
require "floss_funding/lockfile"
require "floss_funding/validators"

# Now declare some constants
module FlossFunding
  # Debug toggle controlled by ENV; set true when ENV['FLOSS_CFG_FUND_DEBUG'] case-insensitively equals "true".
  DEBUG = begin
    v = ENV.fetch("FLOSS_CFG_FUND_DEBUG", nil)
    v.to_s.casecmp("true") == 0
  rescue StandardError
    false
  end

  # The file name to look for in the project root.
  # @return [String]
  CONFIG_FILE_NAME = ".floss_funding.yml"

  FF_ROOT = File.realpath(File.join(File.dirname(__FILE__), ".."))

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
    :detained => "detained",
  }.freeze
  STATE_VALUES = STATES.values.freeze

  # The default state is unknown / unactivated until proven otherwise.
  DEFAULT_STATE = STATES[:unactivated]

  # First month index against which base words are validated.
  # Do not change once released as it would invalidate existing activation keys.
  # @return [Integer]
  START_MONTH = Month.new(2025, 7).to_i # Don't change this, not ever!
  # Sanity check to ensure the month gem and month-serializer gem are in sync with expectations from this repo
  # TODO: If the number is incorrect, and too high, what happens with previously valid keys?
  # TODO: If the number is incorrect, and too low, what happens with previously valid keys?
  warn "[floss_funding] Expected START_MONTH to be be 24307" unless START_MONTH == 24307

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
  # Time source for month arithmetic (UTC); overridable for tests.
  # Always stored as a UTC Time to avoid local timezone issues.
  # @return [Time]
  @loaded_at = Time.now.utc.freeze

  # Current Month index for time-based key validity
  # @return [Integer]
  @loaded_month = Month.new(@loaded_at.year, @loaded_at.month).to_i

  # Number of valid words based on the current month window
  # @return [Integer]
  @num_valid_words_for_month = @loaded_month - ::FlossFunding::START_MONTH

  # The computed base words for a given month window
  #
  # @return [Hash[Integer, Set<String>]]]
  @base_words_set_cache = {}

  # All available base words
  #
  # @see {file:../base_words.txt All Base Words}
  #
  # @return [Array<String>]
  @base_words_all =
    begin
      words = []
      begin
        File.foreach(::FlossFunding::BASE_WORDS_PATH) { |line| words << line.chomp }
      rescue StandardError
        warn("[FlossFunding] Unable to read base words file: #{::FlossFunding::BASE_WORDS_PATH}")
        words = []
      end
      words.freeze
    end

  class << self
    # Register a minimal activation event for wedge-injected libraries to ensure
    # they are counted in the final summary without performing config discovery.
    # @param base [Module] the including module
    # @param custom_namespace [String, nil] optional override namespace
    def register_wedge(base, custom_namespace = nil, contraindicated = false)
      # Derive namespace string
      ns_name = (custom_namespace.is_a?(String) && custom_namespace.strip != "") ? custom_namespace : base.name.to_s

      # Build Namespace (derives activation key/state from ENV)
      namespace = ::FlossFunding::Namespace.new(ns_name, base)

      # Derive a library (gem) name from the namespace: underscore segments and downcase
      # Example: "FlossFunding" => "floss_funding"; "My::Lib" => "my_lib"
      derived_lib_name = ns_name.split("::").map { |seg| ::FlossFunding::UnderBar.to_under_bar(seg) }.join("__").downcase

      # Minimal configuration: include required keys so downstream consumers have something sensible
      cfg_hash = {
        "library_name" => ["wedge_#{derived_lib_name}"],
        "funding_uri" => ["https://floss-funding.dev"],
      }
      config = ::FlossFunding::Configuration.new(cfg_hash)

      # Minimal Library record; many fields are nil or placeholders in wedge mode
      library = ::FlossFunding::Library.new(
        derived_lib_name,        # library_name
        namespace,               # ns
        custom_namespace,        # custom_ns
        base.name.to_s,          # base_name
        nil,                     # including_path
        nil,                     # root_path
        nil,                     # config_path
        namespace.env_var_name,  # env_var_name
        config,                  # configuration
        nil,                     # silent
      )

      # Event with the derived state and key
      event = ::FlossFunding::ActivationEvent.new(
        library,
        namespace.activation_key,
        namespace.state,
        nil,
      )

      add_or_update_namespace_with_event(namespace, event)
      initiate_begging(event) unless contraindicated

      event
    rescue StandardError => e
      # Never raise; wedge registration is best-effort only
      ::FlossFunding.error!(e, "register_wedge")
      nil
    end
    # Read the deterministic time source
    #
    # @see @loaded_at
    #
    # @return [Time]
    attr_reader :loaded_at

    # Expose the discovered project root (may be nil when running inside this gem's own repo)
    # @return [String, nil]
    def project_root
      ::FlossFunding::ConfigFinder.project_root
    end

    # Tasks for both development and test environments
    def install_tasks
      load("floss_funding/tasks.rb")
    end

    # Debug logging helper. Only outputs when FlossFunding::DEBUG is true.
    # Accepts either a message (or multiple args joined by space) or a block
    # for lazy construction of the message.
    # @param args [Array<Object>] message parts to join with space
    # @yieldreturn [String] optional block returning the message
    # @return [void]
    def debug_log(*args)
      return unless ::FlossFunding::DEBUG
      msg = if block_given?
        yield
      else
        args.map(&:to_s).join(" ")
      end
      # Prefer Logger to file when configured and available; otherwise STDOUT
      logger = debug_logger
      if logger
        begin
          logger.debug(msg.to_s)
          return
        rescue StandardError
          # fall back to STDOUT below
        end
      end
      puts(msg)
    rescue StandardError
      # Never fail the caller due to logging issues
      nil
    end

    # Global error flag; when set true, library should become inert.
    def errored?
      @mutex.synchronize { !!@errored }
    end

    # Mark an internal error, log useful context for diagnostics, and set inert flag.
    # @param error [Exception]
    # @param where [String, nil] context label
    def error!(error, where = nil)
      begin
        lbl = where ? "[ERROR][#{where}]" : "[ERROR]"
        msg = "#{lbl} #{error.class}: #{error.message}"
        debug_log { msg }
        bt = (error.backtrace || [])[0, 5].join("\n")
        debug_log { "#{lbl} backtrace:\n#{bt}" } unless bt.empty?
      rescue StandardError
        # ignore logging failures
      ensure
        @mutex.synchronize { @errored = true }
      end
      true
    end

    # Lazily build a Logger instance when FLOSS_CFG_FUNDING_LOGFILE is set and 'logger' is available.
    # Returns a Logger or nil when unavailable or initialization failed.
    def debug_logger
      path = begin
        ENV["FLOSS_CFG_FUNDING_LOGFILE"]
      rescue StandardError
        nil
      end
      return if path.nil? || path.to_s.strip.empty?

      begin
        require "logger"
      rescue LoadError
        return
      rescue StandardError => e
        # Log but do not set inert for logger init failures
        debug_log { "[WARN][debug_logger] #{e.class}: #{e.message}" }
        return
      end

      @mutex.synchronize do
        return @debug_logger if defined?(@debug_logger) && @debug_logger

        # Ensure directory exists; best-effort
        begin
          dir = File.dirname(path)
          FileUtils.mkdir_p(dir) unless dir.nil? || dir.empty? || Dir.exist?(dir)
        rescue StandardError
          # ignore; Logger.new may still succeed if dir already exists or is current dir
        end

        begin
          # Truncate the debug log file on first initialization to keep runs readable
          begin
            File.open(path, "w") { |f| f.truncate(0) }
          rescue StandardError => e
            debug_log { "[WARN][debug_logger] unable to truncate #{path}: #{e.class}: #{e.message}" }
          end

          logger = Logger.new(path)
          logger.level = Logger::DEBUG
          # Keep output minimal: message only with newline
          logger.formatter = proc { |_severity, _datetime, _progname, message| (message.to_s.end_with?("\n") ? message.to_s : message.to_s + "\n") }
          @debug_logger = logger
        rescue StandardError
          @debug_logger = nil
        end

        @debug_logger
      end
    end

    # Accessor for namespaces hash: keys are namespace strings, values are Namespace objects
    # @return [Hash{String => ::FlossFunding::Namespace}]
    def namespaces
      @mutex.synchronize { @namespaces.dup }
    end

    # Replace the namespaces hash (expects `Hash{String => ::FlossFunding::Namespace}`)
    def namespaces=(value)
      @mutex.synchronize { @namespaces = value }
    end

    # Global silenced flag accessor (boolean)
    # @return [Boolean]
    def silenced
      @mutex.synchronize { @silenced }
    end

    # Set the global silenced flag
    # @param value [Boolean]
    # @return [void]
    def silenced=(value)
      @mutex.synchronize { @silenced = !!value }
    end

    def add_or_update_namespace_with_event(namespace, event)
      @mutex.synchronize do
        ns_obj = namespace
        # Append in place to reduce allocations and avoid extra @mutex churn
        ns_obj.activation_events << event
        @namespaces[namespace.name] = ns_obj
        begin
          lib_name = (event.library ? event.library.library_name : nil)
          ::FlossFunding.debug_log { "[registry] add_or_update ns=#{namespace.name.inspect} events=#{ns_obj.activation_events.size} state=#{event.state} lib=#{lib_name.inspect}" }
        rescue StandardError
          # ignore log errors
        end
      end
    end

    # All namespaces that have any activation events recorded
    # Returns array of Namespace objects
    # @return [Array<::FlossFunding::Namespace>]
    def all_namespaces
      @mutex.synchronize { @namespaces.values.flatten.dup }
    end

    # Configuration storage and helpers (derived from namespaces and activation events)
    # When namespace is nil, returns a Hash mapping namespace String => Array<FlossFunding::Configuration>.
    # When namespace is provided, returns FlossFunding::Configuration for that namespace (or nil if not found).
    def configurations(namespace = nil)
      @mutex.synchronize do
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
      @mutex.synchronize do
        @namespaces.transform_values { |nobj| nobj.env_var_name }
      end
    end

    # Reads the first N lines from the base words file to validate paid activation keys.
    #
    # @param num_valid_words [Integer, nil] number of words to read from the word list
    # @return [Array<String>] the first N words; empty when N is nil or zero
    # Reads base words used to validate paid activation keys.
    # When called without an argument, uses the current month window to
    # determine how many words are valid.
    def base_words(num_valid_words = nil)
      n = num_valid_words.nil? ? @num_valid_words_for_month : num_valid_words
      return [] if n.nil? || n.zero?

      @base_words_all.slice(0, n)
    end

    # Check whether a plaintext activation base word is currently valid
    # @param plain_text [String]
    # @return [Boolean]
    def check_activation(plain_text)
      return false if @num_valid_words_for_month.nil? || @num_valid_words_for_month <= 0
      # Cache a Set for fast membership per current n
      sets = @base_words_set_cache
      set = sets[@num_valid_words_for_month]
      unless set
        words = base_words(@num_valid_words_for_month)
        # Warning inside a cache-protected lookup means it should only happen once per process, at most.
        warn("[FlossFunding] ZOMG! Base words missing. Did you time travel? Is it #{@loaded_month}? Is system clock set in the past?") if words.empty?
        set = Set.new(words)
        sets[@num_valid_words_for_month] = set
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
    # @param library_name [String]
    # @return [void]
    def start_begging(namespace, env_var_name, library_name)
      return if ::FlossFunding::ContraIndications.at_exit_contraindicated?
      puts %(FLOSS Funding: Activation key missing for #{library_name} (#{namespace}). Set ENV["#{env_var_name}"] to your activation key; details will be shown at exit.)
    end

    def initiate_begging(event)
      library = event.library
      ns = library.namespace
      env_var_name = ::FlossFunding::UnderBar.env_variable_name(ns)
      library_name = library.library_name
      activation_key = event.activation_key

      # On-load nag sentinel: allow each library to nag at most once per lockfile lifetime
      lock = ::FlossFunding::Lockfile.on_load

      case event.state
      when ::FlossFunding::STATES[:activated]
        nil
      when ::FlossFunding::STATES[:invalid]
        unless lock && lock.nagged?(library)
          lock.record_nag(library, event, "on_load") if lock
          ::FlossFunding.start_coughing(activation_key, ns, env_var_name)
        end
      when ::FlossFunding::STATES[:detained]
        unless lock && lock.nagged?(library)
          lock.record_nag(library, event, "on_load") if lock
          puts %(FLOSS Funding: Configuration for #{library_name} (#{ns}) contains invalid values and has been detained; details will be shown at exit.) unless ::FlossFunding::ContraIndications.at_exit_contraindicated?
        end
      else
        unless lock && lock.nagged?(library)
          lock.record_nag(library, event, "on_load") if lock
          ::FlossFunding.start_begging(ns, env_var_name, library_name)
        end
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
require "floss_funding/library"
require "floss_funding/namespace"
require "floss_funding/activation_event"
require "floss_funding/contra_indications"
require "floss_funding/inclusion"
require "floss_funding/poke"
require "floss_funding/final_summary"
# require "floss_funding/wedge" # Used independently, loaded discretely

# Dog Food test #1
require "gem_mine"

# Dog Food test #2
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
    FlossFunding.debug_log { "[at_exit] hook entered" }
    # 1. Preserve exit status by ensuring no exceptions bubble out of this block.
    # 2. Respect silence signal and short-circuit when contraindicated.
    if FlossFunding::ContraIndications.at_exit_contraindicated?
      FlossFunding.debug_log { "[at_exit] contraindicated; skipping summary" }
      next
    end

    FlossFunding.debug_log { "[at_exit] building FinalSummary; namespaces=#{FlossFunding.all_namespaces.size}" }
    # 2B. Not silent: build and render the final summary.
    FlossFunding::FinalSummary.new
  rescue StandardError => e
    # Never allow our errors to flip a successful exit into a failure, but record them and
    # switch to inert mode for subsequent runs.
    FlossFunding.error!(e, "at_exit")
  end
end
# :nocov:
