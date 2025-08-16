# frozen_string_literal: true

require "time"

module FlossFunding
  # Simple lockfile to prevent duplicate output from subprocesses.
  #
  # Behavior:
  # - Path defaults to project_root/.floss_funding.lock
  # - Can be overridden via ENV["FLOSS_FUNDING_CFG_LOCK"]
  #   - must end with .lock
  #   - if absolute, must start with File::SEPARATOR
  #   - if relative, resolved against project_root
  # - File contains:
  #   1) creator PID
  #   2) creation timestamp (UTC ISO8601)
  #   3) sentinel PID (optional)
  #   4) sentinel timestamp (UTC ISO8601, optional)
  # - Create on load; delete on exit only when older than threshold and owned
  module Lockfile
    class << self
      # Compute the lockfile path according to rules.
      # @return [String, nil]
      def path
        root = ::FlossFunding.project_root
        return if root.nil?

        env_val = ENV["FLOSS_FUNDING_CFG_LOCK"]
        candidate = if env_val && !env_val.strip.empty?
          validate_env_lock(env_val, root)
        end

        candidate || File.join(root, default_filename)
      end

      # Whether a lockfile currently exists (regardless of owner)
      # @return [Boolean]
      def exists?
        p = path
        p && File.exist?(p)
      rescue StandardError
        false
      end

      # Create the lockfile if it does not already exist. If it exists, in DEBUG,
      # log that it may be due to a subprocess.
      # Register at_exit cleanup to remove the lockfile if we created it (owns?)
      # @return [void]
      def install!
        p = path
        return unless p # no project root detected

        created = false
        if File.exist?(p)
          ::FlossFunding.debug_log { "[floss_funding] Lockfile already present at #{p}; may be a subprocess." }
        else
          begin
            # Ensure parent directory exists if relative override had subdirs
            dir = File.dirname(p)
            Dir.mkdir(dir) unless Dir.exist?(dir)
          rescue StandardError
            # ignore; File.open will raise next
          end
          begin
            File.open(p, "w") do |f|
              f.puts(Process.pid.to_s)
              f.puts(Time.now.utc.iso8601)
            end
            created = true
          rescue StandardError
            # If we can't create the file, ignore silently to not break users
            created = false
          end
        end

        at_exit do
          begin
            # Gate at-exit output via sentinel mechanism. If contraindicated, the
            # global at_exit should see that and skip printing.
            # We do cleanup independently, respecting age threshold.
            cleanup! if created
          rescue StandardError
            # never raise from at_exit
          end
        end
      end

      # Gate whether at-exit output should be allowed based on a per-lockfile sentinel.
      # Returns true when at-exit should be suppressed (contraindicated), false when allowed.
      # :nocov:
      def at_exit_contraindicated?
        p = path
        return false unless p && File.exist?(p) # no lockfile => don't contraindicate here

        begin
          File.open(p, "+r") do |f|
            # Try to take an exclusive, non-blocking lock (best-effort; proceed even if not supported)
            begin
              f.flock(File::LOCK_EX | File::LOCK_NB)
            rescue StandardError
              # ignore flock errors and proceed
            end

            lines = read_lines_from_path(p)
            # If sentinel already present (3rd and 4th lines exist), contraindicate
            if lines.length >= 4
              return true
            end

            # Otherwise, write sentinel (append or rewrite preserving first two lines)
            creator_pid = (lines[0] || "").to_s.strip
            created_at = (lines[1] || "").to_s.strip
            f.rewind
            f.truncate(0)
            f.puts(creator_pid)
            f.puts(created_at)
            f.puts(Process.pid.to_s)
            f.puts(Time.now.utc.iso8601)
            f.flush
            begin
              f.fsync
            rescue
              nil
            end
            return false # allowed
          end
        rescue StandardError
          # Fallback: best-effort append sentinel without locking
          begin
            if p && File.exist?(p)
              File.open(p, "a") do |fa|
                fa.puts(Process.pid.to_s)
                fa.puts(Time.now.utc.iso8601)
              end
            end
          rescue StandardError
            # ignore
          end
          # Allow once
          false
        end
      end
      # :nocov:

      # Delete the lockfile if we are the owner (PID matches) and it's older than threshold
      # @return [void]
      def cleanup!
        p = path
        return unless p && File.exist?(p)

        return unless owned_by_self?(p)

        # Only delete when age exceeds threshold
        begin
          age = age_seconds(p)
          threshold = max_age_seconds
          return unless !age.nil? && age > threshold
        rescue StandardError
          # If we can't compute age, keep the file (sticky)
          return
        end

        File.delete(p)
      rescue StandardError
        # ignore cleanup errors
      end

      private

      def default_filename
        ".floss_funding.lock"
      end

      # :nocov:
      def max_age_seconds
        Integer(ENV.fetch("FLOSS_CFG_FUNDING_SEC_PER_NAG_MAX", "2400"))
      rescue StandardError
        2400
      end

      def age_seconds(p)
        lines = File.readlines(p)
        ts = (lines[1] || "").to_s.strip
        return if ts.empty?
        t = Time.iso8601(ts)
        (Time.now.utc - t).to_i
      rescue StandardError
        nil
      end

      def read_lines_safe(io)
        io.rewind
        io.read.to_s.split(/\r?\n/)
      rescue StandardError
        []
      end

      def read_lines_from_path(p)
        File.read(p).to_s.split(/\r?\n/)
      rescue StandardError
        []
      end

      def blank?(s)
        s.nil? || s.strip.empty?
      end
      # :nocov:

      # Validate ENV override according to rules; return absolute resolved path or nil on invalid
      def validate_env_lock(val, root)
        v = val.to_s.strip
        return unless v.end_with?(".lock")

        if v.start_with?(File::SEPARATOR)
          # absolute
          v
        else
          # relative to project root
          File.expand_path(File.join(root, v))
        end
      rescue StandardError
        nil
      end

      def owned_by_self?(p)
        first_line = File.open(p, "r") { |f| f.gets.to_s }
        first_line.to_s.strip == Process.pid.to_s
      rescue StandardError
        false
      end
    end
  end
end
