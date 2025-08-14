# frozen_string_literal: true

module FlossFunding
  # Public API for including FlossFunding into your library/module.
  #
  # Usage patterns:
  #
  # 1. Traditional namespace (uses the including module's name):
  #
  #     module MyGemLibrary
  #       include FlossFunding::Poke.new(__FILE__)
  #     end
  #
  # 2. Arbitrary custom namespace (can add version, or anything else):
  #
  #     module MyGemLibrary
  #       include FlossFunding::Poke.new(__FILE__, namespace: "Custom::Namespace::V4")
  #     end
  #
  # 3. Explicitly disable config discovery (including gem_name) by passing nil:
  #
  #     module MyGemLibrary
  #       include FlossFunding::Poke.new(nil)
  #     end
  #
  # 4. Provide an explicit config path (bypasses directory-walk search):
  #
  #     module MyGemLibrary
  #       include FlossFunding::Poke.new(__FILE__, config_path: "/path/to/.floss_funding.yml")
  #     end
  #
  # In all cases, the first parameter should be a String file path (e.g., `__FILE__`) or nil to disable discovery.
  module Poke
    # Use class << self for defining class methods
    class << self
      # Hook invoked when including FlossFunding::Poke directly.
      #
      # Direct inclusion is not supported; always use `Poke.new(__FILE__, ...)`.
      #
      # @param base [Module] the target including module
      # @raise [::FlossFunding::Error] always, instructing correct usage
      def included(base)
        raise ::FlossFunding::Error, "Do not include FlossFunding::Poke directly. Use include FlossFunding::Poke.new(__FILE__, namespace: optional_namespace)."
      end

      # Builds a module suitable for inclusion which sets up FlossFunding.
      #
      # @param including_path [String, nil] the including file path (e.g., `__FILE__`) or nil to disable discovery
      # @param options [Hash] options hash for configuration
      # @option options [String, nil] :namespace optional custom namespace for activation key
      # @option options [Object, nil] :silent optional silence flag or callable to request global silence
      # @option options [String, nil] :config_path explicit path to a config file; bypasses directory-walk search when provided
      # @return [Module] a module that can be included into your namespace
      def new(including_path, options = {})
        silent_opt = options[:silent]

        # If this library explicitly requests boolean silence, set it so libraries loaded later will be silenced;
        # callables are deferred to at_exit.
        if !silent_opt.respond_to?(:call) && silent_opt
          ::FlossFunding.silenced ||= true
        end

        # Environment-based contraindications (global silenced flag, CI, broken Dir.pwd, non-TTY)
        if ::FlossFunding::ContraIndications.poke_contraindicated?
          # Return an inert module (no registration) when contraindicated
          return Module.new
        end

        namespace = options[:namespace]
        wedge = options[:wedge]
        config_path_opt = options[:config_path]

        # an anonymous module that will set up an activation key Check when included
        Module.new do
          define_singleton_method(:included) do |base|
            # Sync deterministic time source to current time (respects Timecop.freeze)
            ::FlossFunding.now_time

            if wedge
              # Only inject the Fingerprint, no configuration/discovery
              base.extend(::FlossFunding::Fingerprint)
              next
            end

            # Validate presence of a .floss_funding.yml with required keys before proceeding
            # Determine config path
            cfg_path = config_path_opt
            if cfg_path.nil? && including_path
              start_dir = File.dirname(including_path)
              cfg_path = ::FlossFunding::ConfigFinder.find_config_path(start_dir)
            end

            unless cfg_path && File.file?(cfg_path) && File.basename(cfg_path) == ".floss_funding.yml"
              raise ::FlossFunding::Error, "Missing required .floss_funding.yml file; run `rake floss_funding:install` to create one."
            end

            begin
              data = YAML.safe_load(File.read(cfg_path)) || {}
            rescue StandardError
              data = {}
            end

            missing = ::FlossFunding::REQUIRED_YAML_KEYS.reject { |k| data.key?(k) && data[k] && data[k].to_s.strip != "" }
            unless missing.empty?
              raise ::FlossFunding::Error, ".floss_funding.yml missing required keys: #{missing.join(", ")}"
            end

            FlossFunding::Inclusion.new(base, namespace, including_path, silent_opt, options)
          end
        end
      end
    end
  end
end
