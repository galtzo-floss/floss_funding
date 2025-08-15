# frozen_string_literal: true

module FlossFunding
  # Represents the runtime inclusion context for a given inclusion of FlossFunding.
  # Encapsulates discovery (Namespace, Library), activation state, and the
  # ActivationEvent generated from an include site.
  class Inclusion
    include ::FlossFunding::FileFinder

    # @return [Module]
    attr_reader :base
    # @return [String]
    attr_reader :including_path
    # @return [String]
    attr_reader :library_root_path
    # @return [String]
    attr_reader :library_name
    # @return [String, nil]
    attr_reader :custom_namespace
    # @return [#call, nil]
    attr_reader :silent
    # @return [String]
    attr_reader :name
    # @return [FlossFunding::Namespace]
    attr_reader :namespace
    # @return [FlossFunding::Library]
    attr_reader :library
    # @return [String]
    attr_reader :activation_key
    # @return [String]
    attr_reader :state
    # @return [FlossFunding::ActivationEvent]
    attr_reader :event
    # @return [Hash]
    attr_reader :options
    # @return [String, nil]
    attr_reader :config_path
    # @return [Hash]
    attr_reader :config_data
    # @return [FlossFunding::Configuration]
    attr_reader :configuration

    # Build an Inclusion and register its activation event.
    #
    # @param base [Module] the including module
    # @param custom_namespace [String, nil]
    # @param including_path [String, nil]
    # @param options [Hash] additional options (e.g., :config_path)
    # @option options [#call] :silent (nil)
    def initialize(base, custom_namespace, including_path, options = {})
      @options = options.dup
      @base = base
      @including_path = including_path
      @silent = @options.delete(:silent)
      @config_path = @options.delete(:config_path)
      # Assign early so validation sees the actual provided value
      @custom_namespace = custom_namespace

      validate_inputs!

      @name =
        if custom_namespace.is_a?(String) && !custom_namespace.empty?
          @custom_namespace = custom_namespace
        else
          @base_name = base.name
        end

      ### NAMESPACE (not frozen!) ###
      @namespace = FlossFunding::Namespace.new(@name, base)
      @activation_key = @namespace.activation_key
      @state = @namespace.state

      reason = discover_library_root_path
      raise ::FlossFunding::Error, "Missing library root path due to: #{reason}" unless @library_root_path

      if @config_path
        discover_config_path
      else
        discover_config_path_from_library_root
      end

      # Derive config data from @config_path by parsing .floss_funding.yml.
      data_from_config_file
      validate_config_data

      @library_name = @config_data["library_name"].first

      ### CONFIGURATION (frozen object!) ###
      @configuration = FlossFunding::Configuration.new(@config_data)

      ### LIBRARY (frozen object!) ###
      @library = ::FlossFunding::Library.new(
        @library_name,
        @namespace,
        @custom_namespace,
        @base_name,
        @including_path,
        @library_root_path,
        @config_path,
        @namespace.env_var_name,
        @configuration,
        @silent,
      )

      ### ACTIVATION EVENT (frozen object!) ###
      @event = ::FlossFunding::ActivationEvent.new(
        @library,
        @activation_key,
        @state,
        @silent,
      )

      FlossFunding.add_or_update_namespace_with_event(@namespace, @event)
      FlossFunding.initiate_begging(@event)
    end

    private

    # @return void
    # @raise [FlossFunding::Error]
    def validate_inputs!
      unless @including_path.is_a?(String) || @including_path.nil?
        # Preserve legacy error wording so existing specs continue to match
        raise ::FlossFunding::Error, "including_path must be a String file path (e.g., __FILE__), got #{@including_path.class}"
      end
      unless @base.respond_to?(:name) && @base.name && @base.name.is_a?(String)
        raise ::FlossFunding::Error, "base must have a name (e.g., MyGemLibrary), got #{@base.inspect}"
      end
      unless @custom_namespace.nil? || @custom_namespace.is_a?(String) && !@custom_namespace.empty?
        raise ::FlossFunding::Error, "custom_namespace must be nil or a non-empty String (e.g., MyGemLibrary), got #{@custom_namespace.inspect}"
      end
    end

    # YAML.safe_load returns a hash with string keys.
    # YAML.safe_load returns a hash with values of the following types:
    # • Basic Data Types:
    #     * String
    #     * Integer
    #     * Float
    #     * TrueClass (true) and FalseClass (false)
    #     * NilClass (nil)
    # • Arrays:
    #     * Array (only if all elements are of the above basic types)
    # • Hash:
    #     * Hash (only if both keys and values are of the above basic types)
    def data_from_config_file
      yaml_cfg =
        begin
          YAML.safe_load(File.read(@config_path)) || {}
        rescue StandardError => e
          # Expect failure again below in the required keys check.
          # Default config can't supply all required keys.
          # Warning here, and then failing again below,
          # gives the implementer maximum information about what went wrong,
          # reducing the loops needed to get FlossFunding setup correctly!
          warn("[floss_funding] YAML.safe_load(#{@config_path}) failure: #{e.class}: #{e.message}")
          {}
        end

      # Load defaults from config/default.yml and normalize values to arrays
      default_cfg = ::FlossFunding::ConfigLoader.default_configuration

      @config_data = {}
      # ensure all keys present and arrays
      (default_cfg.keys | yaml_cfg.keys).each do |k|
        @config_data[k] = ::FlossFunding::Config.normalize_to_array(yaml_cfg.key?(k) ? yaml_cfg[k] : default_cfg[k])
      end
      augment_derived_fields!
      @config_data.freeze
    end

    # augment with derived fields
    def augment_derived_fields!
      @config_data["silent_callables"] = ::FlossFunding::Config.normalize_to_array(@silence)
    end

    def validate_config_data
      missing = ::FlossFunding::REQUIRED_YAML_KEYS.reject { |k| @config_data.key?(k) && @config_data[k] && @config_data[k].to_s.strip != "" }
      unless missing.empty?
        raise ::FlossFunding::Error, "YAML (#{@config_path}) is missing required keys: #{missing.join(", ")}"
      end
    end

    def discover_library_root_path
      return "missing including path" unless @including_path

      key = File.expand_path(@including_path)
      return "missing key" unless key

      root_indicator_file = find_file_upwards(FlossFunding::CONFIG_FILE_NAME, key)
      return "missing root_indicator_file" unless root_indicator_file

      dir = File.dirname(root_indicator_file)
      return "missing dir" unless dir

      @library_root_path = dir
    end

    def discover_config_path
      # Library config handling:
      # - Only use an explicit `:config_path` if provided (absolute or relative to including_path)
      # - Do not perform any directory-walk or project-level discovery here
      if @config_path.start_with?(File::SEPARATOR)
        # Treat as absolute when rooted at '/'
        # No change needed
      else
        unless @including_path
          raise ::FlossFunding::Error, "Relative config_path requires including_path; provide an absolute :config_path or pass a valid including_path (e.g., __FILE__)."
        end
        expanded_config_path = File.expand_path(@config_path, File.dirname(@including_path))
        FlossFunding.debug_log { "[Inclusion] #{expanded_config_path.inspect} from #{@config_path.inspect} relative to including_path #{@including_path.inspect}" }
        @config_path = expanded_config_path
      end

      unless File.file?(@config_path) && File.basename(@config_path) == ".floss_funding.yml"
        raise ::FlossFunding::Error, "Missing required .floss_funding.yml at #{@config_path.inspect}; run `rake floss_funding:install` to create one."
      end
    end

    # Set library_root_path.
    # Computes a library root starting from a given directory by looking for
    # common Bundler/gemspec indicators. Anchors the search to `@including_path`.
    #
    # @return void
    def discover_config_path_from_library_root
      @config_path = File.join(@library_root_path, FlossFunding::CONFIG_FILE_NAME)

      nil
    end
  end
end
