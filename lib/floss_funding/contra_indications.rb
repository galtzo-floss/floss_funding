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
      def poke_contraindicated?
        # Callable silencers do not apply during load; only at-exit.
        # For early short-circuiting we honor the global silenced flag only.
        return true if ::FlossFunding.silenced

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

        # Non-TTY environments: suppress poke/setup side effects (mirror at-exit logic)
        begin
          return true unless STDOUT.tty?
        rescue StandardError
          return true
        end

        # Lockfile presence contraindicates Poke setup (e.g., subprocesses)
        begin
          return true if ::FlossFunding::Lockfile.exists?
        rescue StandardError
          # ignore issues resolving lockfile
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
        # Honor global flags first
        return true if ::FlossFunding.silenced
        return true if ::FlossFunding::Constants::SILENT

        # Non-TTY environments: suppress at-exit output
        begin
          return true unless STDOUT.tty?
        rescue StandardError
          return true
        end

        # Lockfile sentinel gating: only allow one process per window to print at-exit
        begin
          return true if ::FlossFunding::Lockfile.at_exit_contraindicated?
        rescue StandardError
          # On any error, err on suppression side only if lockfile exists
          begin
            return true if ::FlossFunding::Lockfile.exists?
          rescue StandardError
            # ignore
          end
        end

        configurations = ::FlossFunding.configurations
        configurations.any? do |_library, cfgs|
          configs_arr = cfgs.is_a?(Array) ? cfgs : [cfgs]
          configs_arr.any? do |cfg|
            values = if cfg.respond_to?(:to_h)
              Array(cfg.to_h["silent_callables"]) # preferred when available
            elsif cfg.is_a?(Hash)
              Array(cfg["silent_callables"]) # may be nil/array/scalar
            else
              []
            end

            values.any? do |v|
              begin
                v.respond_to?(:call) ? !!v.call : false
              rescue StandardError
                # If callable raises, treat it as contraindicated to avoid unknown global state
                true
              end
            end
          end
        end
      end
    end
  end
end
