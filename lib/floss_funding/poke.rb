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
        # an anonymous module that will set up an activation key Check when included
        Module.new do
          define_singleton_method(:included) do |base|
            # Sync deterministic time source to current time (respects Timecop.freeze)
            ::FlossFunding.now_time

            FlossFunding::Inclusion.new(base, namespace, including_path, silent_opt)
          end
        end
      end
    end
  end
end
