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
        # Environment-based contraindications (includes global silence, CI, broken Dir.pwd)
        return Module.new if ::FlossFunding::ContraIndications.poke_contraindicated?

        namespace = options[:namespace]
        silent_opt = options[:silent]
        # an anonymous module that will set up an activation key Check when included
        Module.new do
          define_singleton_method(:included) do |base|
            project = FlossFunding::Project.new(base, namespace, including_path, silent_opt)
            # Only handle true here, because the :call evaluations should happen as late as possible,
            # just prior to printing output.
            return if project.silent == true

            # Now call the begging method after extending
            base.floss_funding_initiate_begging(project.event)
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
        # Backwards-compatible delegator to Project.new
        project = ::FlossFunding::Project.new(base, custom_namespace, including_path, silent_opt)
        # Only handle true here, because the :call evaluations should happen as late as possible,
        #   just prior to printing output.
        return if project.silent == true
        # Now call the begging method after extending
        base.floss_funding_initiate_begging(project.event)
      end
    end
  end
end
