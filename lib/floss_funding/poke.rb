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
  # 3. Explicitly disable config discovery (including library_name) by passing nil and wedge: true:
  #
  #     module MyGemLibrary
  #       include FlossFunding::Poke.new(nil, wedge: true)
  #     end
  #
  # 4. Provide a custom config file name located at the library root:
  #
  #     module MyGemLibrary
  #       include FlossFunding::Poke.new(__FILE__, config_file: ".my_custom.yml")
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
      # @option options [String, nil] :config_file alternate file name located at the library root; defaults to .floss_funding.yml
      # @option options [Boolean, nil] :wedge explicitly disable config discovery (including library_name)
      # @return [Module] a module that can be included into your namespace
      def new(including_path, options = {})
        opts = options.dup
        silent_opt = opts[:silent]

        # If this library explicitly requests boolean silence, set it so libraries loaded later will be silenced;
        # callables are deferred to at_exit.
        if !silent_opt.respond_to?(:call) && silent_opt
          # don't deal with silent again unless it is callable
          opts.delete(:silent)
          ::FlossFunding.silenced ||= true
        end

        namespace = options.delete(:namespace)
        # When including_path is nil, disable discovery, by enforcing wedge: true
        wedge = options.delete(:wedge) || including_path.nil?
        contraindicated = ::FlossFunding::ContraIndications.poke_contraindicated?

        # an anonymous module that will set up an activation key check when included
        Module.new do
          define_singleton_method(:included) do |base|
            # Always extend Fingerprint first, before any validations or short-circuits
            base.extend(::FlossFunding::Fingerprint)

            # After fingerprinting, handle short-circuits
            # In wedge mode, we still register a minimal event so at_exit summary reflects usage
            if wedge
              begin
                ::FlossFunding.debug_log { "[Poke] wedge registration for #{base.name.inspect} ns=#{(namespace || base.name).inspect}" }
                ::FlossFunding.register_wedge(base, namespace, contraindicated)
              rescue StandardError => e
                # never raise from wedge registration, but record and become inert
                ::FlossFunding.error!(e, "Poke#wedge_registration")
              end
              return
            end

            # Do not proceed with registration/config when contraindicated
            return if contraindicated

            FlossFunding::Inclusion.new(base, namespace, including_path, options)
          end
        end
      end
    end
  end
end
