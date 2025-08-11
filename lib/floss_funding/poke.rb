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
  # In all cases, the first parameter must be a String file path (e.g., `__FILE__`).
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
      # @param including_path [String] the including file path (e.g., `__FILE__`)
      # @param options [Hash] options hash for configuration
      # @option options [String, nil] :namespace optional custom namespace for activation key
      # @option options [Object, nil] :silent optional silence flag or callable to request global silence
      # @return [Module] a module that can be included into your namespace
      def new(including_path, options = {})
        # Global silencer: short-circuit and do nothing when globally silenced.
        return Module.new if ::FlossFunding::Constants::SILENT

        namespace = options[:namespace]
        silent_opt = options[:silent]
        # an anonymous module that will set up an activation key Check when included
        Module.new do
          define_singleton_method(:included) do |base|
            FlossFunding::Poke.setup_begging(base, namespace, including_path, silent_opt)
          end
        end
      end

      # Performs common setup: extends the base with Check, computes the
      # namespace and ENV var name, loads configuration, and initiates begging.
      #
      # @param base [Module] the module including the returned Poke module
      # @param custom_namespace [String, nil] custom namespace or nil to use base.name
      # @param including_path [String] source file path of base (e.g., `__FILE__`)
      # @param silent_opt [Object, nil] optional silence flag or callable stored under "silent" in config
      # @return [void]
      # @raise [::FlossFunding::Error] if including_path is not a String
      # @raise [::FlossFunding::Error] if base.name is not a String
      def setup_begging(base, custom_namespace, including_path, silent_opt = nil)
        unless including_path.is_a?(String)
          raise ::FlossFunding::Error, "including_path must be a String file path (e.g., __FILE__), got #{including_path.class}"
        end
        unless base.respond_to?(:name) && base.name && base.name.is_a?(String)
          raise ::FlossFunding::Error, "base must have a name (e.g., MyGemLibrary), got #{base.inspect}"
        end

        require "floss_funding/check"
        # Extend the base with the checker module first
        base.extend(::FlossFunding::Check)

        # Load configuration from .floss_funding.yml if it exists
        config = ::FlossFunding::Config.load_config(including_path)

        # Three data points needed:
        # 1. namespace (derived from the base class name, config, or param)
        # 2. ENV variable name (derived from namespace)
        # 3. activation key (derived from ENV variable)
        namespace =
          if custom_namespace && !custom_namespace.empty?
            custom_namespace
          else
            base.name
          end

        # Track both the effective base namespace and the custom namespace (if provided)
        config["namespace"] |= Array(base.name)
        config["custom_namespaces"] |= Array(custom_namespace) if custom_namespace && !custom_namespace.empty?

        env_var_name = ::FlossFunding::UnderBar.env_variable_name(
          {
            :namespace => namespace,
          },
        )
        activation_key = ENV.fetch(env_var_name, "")

        # Apply silent option if provided, storing into configuration under this library
        unless silent_opt.nil?
          config["silent"] << silent_opt
        end

        # Store configuration and ENV var name under the effective namespace
        ::FlossFunding.set_configuration(namespace, config)
        ::FlossFunding.set_env_var_name(namespace, env_var_name)

        # Only handle true here, because the :call evaluations should happen as late as possible,
        #   just prior to printing output.
        return if silent_opt == true

        # Now call the begging method after extending
        base.floss_funding_initiate_begging(activation_key, namespace, env_var_name)
      end
    end
  end
end
