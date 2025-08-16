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
    DEFAULT_LOCKFILE_TIMEOUT = 2400 # 40 minutes
    MIN_LOCKFILE_TIMEOUT = 600 # 10 minutes
    class << self
      # Compute the lockfile path according to rules.
      # @return [String, nil]
      def path
        root = ::FlossFunding.project_root
        if root.nil?
          ::FlossFunding.debug_log { "[floss_funding] Lockfile.path: no project_root; skipping lockfile" }
          return
        end

        env_val = ENV["FLOSS_FUNDING_CFG_LOCK"]
        candidate = if env_val && !env_val.strip.empty?
          v = validate_env_lock(env_val, root)
          ::FlossFunding.debug_log { "[floss_funding] Lockfile.path: ENV override provided (#{env_val.inspect}) => #{v || "(invalid)"}" }
          v
        end

        chosen = candidate || File.join(root, default_filename)
        ::FlossFunding.debug_log { "[floss_funding] Lockfile.path: using #{chosen}" }
        chosen
      end

      # Whether a lockfile currently exists (regardless of owner)
      # @return [Boolean]
      def exists?
        p = path
        ex = p && File.exist?(p)
        ::FlossFunding.debug_log { "[floss_funding] Lockfile.exists?: path=#{p || "(nil)"} exists=#{!!ex}" }
        ex
      rescue StandardError
        ::FlossFunding.debug_log { "[floss_funding] Lockfile.exists?: error while checking; returning false" }
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
          ::FlossFunding.debug_log { "[floss_funding] Lockfile already present at #{p}; likely subprocess or previous run" }
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
              creator_pid = Process.pid.to_s
              created_at = Time.now.utc.iso8601
              # 1) creator PID
              f.puts(creator_pid)
              # 2) creation timestamp (UTC ISO8601)
              f.puts(created_at)
              # 3) first printer PID (same as creator)
              f.puts(creator_pid)
              # 4) first printed timestamp (same as created_at)
              f.puts(created_at)
            end
            created = true
            ::FlossFunding.debug_log { "[floss_funding] Lockfile.install!: created lockfile at #{p} (pid=#{Process.pid})" }
          rescue StandardError
            # If we can't create the file, ignore silently to not break users
            ::FlossFunding.debug_log { "[floss_funding] Lockfile.install!: failed to create lockfile at #{p}" }
            created = false
          ensure
            # When in debug, verify existence right after write
            if ::FlossFunding::DEBUG
              exists_now = begin
                File.exist?(p)
              rescue
                false
              end
              ::FlossFunding.debug_log { "[floss_funding] Lockfile.install!: post-write existence check: path=#{p} exists=#{exists_now}" }
            end
          end
        end

        at_exit do
          begin
            # Cleanup independently, respecting age threshold, only if we created it
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
        unless p && File.exist?(p)
          ::FlossFunding.debug_log { "[floss_funding] Lockfile.at_exit_contraindicated?: no lockfile; allow at-exit" }
          return false # no lockfile => don't contraindicate here
        end

        begin
          lines = read_lines_from_path(p)
          creator_pid = (lines[0] || "").to_s.strip
          decision = Process.pid.to_s != creator_pid
          ::FlossFunding.debug_log do
            "[floss_funding] Lockfile.at_exit_contraindicated?: path=#{p} creator_pid=#{creator_pid} current_pid=#{Process.pid} decision=#{decision ? "suppress" : "allow"}"
          end
          # Allow only the creator process to print; all others are contraindicated
          decision
        rescue StandardError
          # On any error reading, err on the side of suppression if the file exists
          ::FlossFunding.debug_log { "[floss_funding] Lockfile.at_exit_contraindicated?: error reading lockfile; suppressing" }
          true
        end
      end
      # :nocov:

      # Delete the lockfile if we are the owner (PID matches) and it's older than threshold
      # @return [void]
      def cleanup!
        p = path
        return unless p && File.exist?(p)

        unless owned_by_self?(p)
          ::FlossFunding.debug_log { "[floss_funding] Lockfile.cleanup!: not owner; skipping delete (path=#{p})" }
          return
        end

        # Only delete when age exceeds threshold
        begin
          age = age_seconds(p)
          threshold = max_age_seconds
          unless !age.nil? && age > threshold
            ::FlossFunding.debug_log { "[floss_funding] Lockfile.cleanup!: under threshold (age=#{age.inspect}s, threshold=#{threshold}s); keep file" }
            return
          end
        rescue StandardError
          # If we can't compute age, keep the file (sticky)
          ::FlossFunding.debug_log { "[floss_funding] Lockfile.cleanup!: error computing age; keeping file" }
          return
        end

        begin
          File.delete(p)
          ::FlossFunding.debug_log { "[floss_funding] Lockfile.cleanup!: deleted lockfile at #{p}" }
        rescue StandardError
          # ignore cleanup errors
          ::FlossFunding.debug_log { "[floss_funding] Lockfile.cleanup!: failed to delete lockfile at #{p}" }
        end
      end

      private

      def default_filename
        ".floss_funding.lock"
      end

      # :nocov:
      def max_age_seconds
        env_val = begin
          Integer(ENV.fetch("FLOSS_CFG_FUNDING_SEC_PER_NAG_MAX", MIN_LOCKFILE_TIMEOUT.to_s))
        rescue StandardError
          MIN_LOCKFILE_TIMEOUT
        end
        # Enforce a minimum lifetime of 10 minutes (600 seconds)
        [env_val, MIN_LOCKFILE_TIMEOUT].max
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
        ::FlossFunding.debug_log { "[floss_funding] Lockfile.validate_env_lock: error validating #{val.inspect}; ignoring" }
        nil
      end

      def owned_by_self?(p)
        first_line = File.open(p, "r") { |f| f.gets.to_s }
        owner = first_line.to_s.strip
        mine = owner == Process.pid.to_s
        ::FlossFunding.debug_log { "[floss_funding] Lockfile.owned_by_self?: path=#{p} owner=#{owner} current=#{Process.pid} mine=#{mine}" }
        mine
      rescue StandardError
        ::FlossFunding.debug_log { "[floss_funding] Lockfile.owned_by_self?: error reading; treating as not owned" }
        false
      end
    end
  end
end
