# frozen_string_literal: true

module FlossFunding
  # Performs environment checks to determine whether FlossFunding should be silenced
  # completely early in the include flow (e.g., CI or unsafe runtime conditions),
  # and whether end-of-process (at_exit) messaging should be suppressed by config.
  class ContraIndications
    class << self
      # Returns true if we should short-circuit and do nothing for poke/setup.
      # - In CI: ENV["CI"] case-insensitively equals "true".
      # - If Dir.pwd raises (defensive check for broken runtime env).
      # @return [Boolean]
      def poke_contraindicated?(silent_opt = nil)
        # Do NOT short-circuit when explicit silent: true is provided.
        # We still need to register the library so that configuration (including the "silent" flag)
        # is available to downstream logic like at-exit suppression.

        # Global silence switch from constants/env
        return true if ::FlossFunding::Constants::SILENT

        begin
          ci_val = ENV.fetch("CI", "")
          return true if ci_val.respond_to?(:casecmp) && ci_val.casecmp("true") == 0
        rescue StandardError
          # If accessing ENV somehow fails, err on the side of silencing
          return true
        end

        begin
          Dir.pwd
        rescue StandardError
          return true
        end

        false
      end

      # Determines whether at-exit (END hook) output should be suppressed based on
      # per-library configuration. This migrates the previous Config.silence_requested?
      # behavior without backward-compatibility.
      #
      # For each library's config, examines the "silent" key values. If any value
      # responds to :call, it will be invoked (with no args) and the truthiness of
      # its return value is used. Otherwise, the value's own truthiness is used.
      # Returns true if any library requests silence; false otherwise.
      #
      # @return [Boolean]
      def at_exit_contraindicated?
        configurations = ::FlossFunding.configurations
        configurations.any? do |_library, cfgs|
          configs_arr = cfgs.is_a?(Array) ? cfgs : [cfgs]
          configs_arr.any? do |cfg|
            values = if cfg.respond_to?(:[])
              Array(cfg["silent"]) # may be nil/array/scalar
            elsif cfg.respond_to?(:to_h)
              Array(cfg.to_h["silent"])
            else
              []
            end
            values.any? do |v|
              begin
                v.respond_to?(:call) ? !!v.call : !!v
              rescue StandardError
                # If callable raises, treat as not silencing
                false
              end
            end
          end
        end
      end
    end
  end
end
