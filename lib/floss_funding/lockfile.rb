# frozen_string_literal: true

require "time"
require "yaml"

module FlossFunding
  # Lockfile re-architecture: YAML-based sentinels for per-library nags.
  # There are two lockfiles with identical structure, but different purposes:
  # - OnLoadLockfile ("floss_funding.on_load.lock"): sentinel for on_load nags
  # - AtExitLockfile ("floss_funding.at_exit.lock"): sentinel for at_exit nags
  #
  # YAML structure:
  # created:
  #   pid: <PID of lockfile creator>
  #   at: <timestamp of creation in UTC>
  #   type: <on_load|at_exit>
  # nags:
  #   <library name>:
  #     namespace: <namespace>
  #     env_variable_name: <env var name>
  #     state: <state>
  #     pid: <PID at nagtime>
  #     at: <timestamp in UTC>
  class LockfileBase
    MIN_SECONDS = 600 # 10 minutes (enforced minimum)
    MAX_SECONDS = 604_800 # 7 days (enforced maximum)

    def initialize
      @path = resolve_path
      @data = load_or_initialize
      # Ensure file exists on first touch
      begin
        persist! if @path
      rescue StandardError
        # ignore
      end
      rotate_if_expired!
    end

    # Absolute path or nil when project_root unknown
    attr_reader :path

    # Has this library already nagged within this lockfile's lifetime?
    # @param library_name [String]
    def nagged?(library_name)
      d = @data
      return false unless d && d["nags"].is_a?(Hash)
      d["nags"].key?(library_name.to_s)
    rescue StandardError
      false
    end

    # Record a nag for the provided library.
    # @param library [FlossFunding::Library]
    # @param event [FlossFunding::ActivationEvent]
    # @param type [String] "on_load" or "at_exit"
    def record_nag(library, event, type)
      return unless @path
      rotate_if_expired!
      @data["nags"] ||= {}
      name = library.library_name.to_s
      return if name.empty? || @data["nags"].key?(name)

      @data["nags"][name] = {
        "namespace" => library.namespace,
        "env_variable_name" => library.env_var_name,
        "state" => event.state,
        "pid" => Process.pid,
        "at" => Time.now.utc.iso8601,
      }
      persist!
    rescue StandardError
      # never raise
    end

    # Remove and recreate lockfile if expired.
    def rotate_if_expired!
      return unless @path && File.exist?(@path)
      created_at = parse_time(@data.dig("created", "at"))
      return unless created_at
      age = Time.now.utc - created_at
      return unless age > max_age_seconds

      begin
        File.delete(@path)
      rescue StandardError
        # ignore delete errors
      end
      @data = fresh_payload
      persist!
    rescue StandardError
      # never raise
    end

    def touch!
      persist!
    rescue StandardError
      nil
    end

    private

    def resolve_path
      root = ::FlossFunding.project_root
      return unless root
      File.join(root, default_filename)
    rescue StandardError
      nil
    end

    def load_or_initialize
      return fresh_payload unless @path && File.exist?(@path)
      begin
        raw = YAML.safe_load(File.read(@path))
      rescue StandardError
        raw = nil
      end
      unless raw.is_a?(Hash) && raw["created"].is_a?(Hash)
        return fresh_payload
      end
      raw
    end

    def fresh_payload
      {
        "created" => {
          "pid" => Process.pid,
          "at" => Time.now.utc.iso8601,
          "type" => lock_type,
        },
        "nags" => {},
      }
    end

    def persist!
      return unless @path
      dir = File.dirname(@path)
      Dir.mkdir(dir) unless Dir.exist?(dir)
      File.open(@path, "w") { |f| f.write(YAML.dump(@data)) }
    rescue StandardError
      # never raise
    end

    def parse_time(s)
      return unless s
      Time.iso8601(s.to_s)
    rescue StandardError
      nil
    end

    # Subclasses must define
    def default_filename
      raise NotImplementedError
    end

    def lock_type
      raise NotImplementedError
    end

    def max_default_seconds
      raise NotImplementedError
    end

    def env_seconds_key
      nil
    end

    def max_age_seconds
      env_val = begin
        Integer(ENV.fetch(env_seconds_key.to_s, max_default_seconds.to_s))
      rescue StandardError
        max_default_seconds
      end
      # enforce bounds
      [[env_val, MIN_SECONDS].max, MAX_SECONDS].min
    end
  end

  # Lockfile that records on_load nags (during Poke/Inclusion time)
  class OnLoadLockfile < LockfileBase
    def default_filename
      "floss_funding.on_load.lock"
    end

    def lock_type
      "on_load"
    end

    def max_default_seconds
      86_400 # 24 hours
    end

    def env_seconds_key
      :FLOSS_CFG_FUNDING_ON_LOAD_SEC_PER_NAG_MAX
    end
  end

  # Lockfile that records at_exit nags (featured info cards rendered at exit)
  class AtExitLockfile < LockfileBase
    def default_filename
      "floss_funding.at_exit.lock"
    end

    def lock_type
      "at_exit"
    end

    def max_default_seconds
      2_400 # 40 minutes
    end

    def env_seconds_key
      :FLOSS_CFG_FUNDING_AT_EXIT_SEC_PER_NAG_MAX
    end
  end

  # Facade to access the two lockfiles from existing call sites
  module Lockfile
    class << self
      def on_load
        @on_load ||= OnLoadLockfile.new
      rescue StandardError
        begin
          OnLoadLockfile.new
        rescue
          nil
        end
      end

      def at_exit
        @at_exit ||= AtExitLockfile.new
      rescue StandardError
        begin
          AtExitLockfile.new
        rescue
          nil
        end
      end

      # Compatibility no-ops for previous API: no longer used for gating.
      def install!
        # Reinitialize to pick up current project_root (may change after load in tests)
        @on_load = OnLoadLockfile.new
        @at_exit = AtExitLockfile.new
        @on_load.touch!
        @at_exit.touch!
        nil
      end

      # Previously used to gate Poke; now always false (never contraindicate discovery)
      def exists?
        false
      end

      # Previously used to gate at-exit globally; now FinalSummary handles per-library gating
      def at_exit_contraindicated?
        false
      end

      # No-op cleanup; rotation is handled automatically per access
      def cleanup!
        nil
      end
    end
  end
end
