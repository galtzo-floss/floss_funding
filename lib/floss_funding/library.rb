# frozen_string_literal: true

require "yaml"
require "rubygems"
require "floss_funding/config_finder"
require "floss_funding/file_finder"
require "floss_funding/project_root"
require "floss_funding/library_root"
require "floss_funding/configuration"

module FlossFunding
  # Represents a single Library (a gem/namespace pair) that has included
  # FlossFunding::Poke. Holds discovery info, configuration, and env details.
  class Library
    NAME_ASSIGNMENT_REGEX = /\bname\s*=\s*(["'])([^"']+)\1/.freeze

    class << self
      # Simple process-lifetime caches
      def yaml_config_cache
        @yaml_config_cache ||= {}
      end

      def gemspec_name_cache
        @gemspec_name_cache ||= {}
      end

      # Lightweight parse for gem name to avoid full Gem::Specification load
      def parse_gemspec_name(gemspec_path)
        begin
          content = File.read(gemspec_path)
          # Look for name assignment patterns like:
          #   spec.name = "my_gem" OR Gem::Specification.new do |spec|; spec.name = 'my_gem'
          if content =~ NAME_ASSIGNMENT_REGEX
            return $2
          end
        rescue StandardError
          # fall through
        end
        nil
      end

      def gem_name_for(gemspec_path)
        abs = File.expand_path(gemspec_path)
        return gemspec_name_cache[abs] if gemspec_name_cache.key?(abs)

        name = parse_gemspec_name(abs)
        if name.nil? || name.empty?
          begin
            spec = Gem::Specification.load(abs)
            name = spec&.name
          rescue StandardError
            name = nil
          end
        end
        gemspec_name_cache[abs] = name if name
        name
      end

      def load_yaml_config(path)
        abs = File.expand_path(path)
        cache = yaml_config_cache
        return cache[abs] if cache.key?(abs)
        data = YAML.safe_load(File.read(abs)) || {}
        cache[abs] = data.freeze
      rescue StandardError
        cache[abs] = {}.freeze
      end

      # Testing helper
      # @note Test shim: used by specs; no internal usage as of 2025-08-13.
      def reset_caches!
        @yaml_config_cache = {}
        @gemspec_name_cache = {}
      end
    end

    # @return [String]
    attr_reader :namespace
    # @return [String]
    attr_reader :base_name
    # @return [String]
    attr_reader :gem_name
    # @return [String]
    attr_reader :including_path
    # @return [String]
    attr_reader :env_var_name
    # @return [String, nil]
    attr_reader :project_root_path
    # @return [String, nil]
    attr_reader :library_root_path
    # @return [String, nil]
    attr_reader :library_config_path
    # @return [String, nil]
    attr_reader :project_config_path
    # @return [Time]
    attr_reader :seen_at
    # @return [Object] may be boolean or callable as provided
    attr_reader :silence
    # @return [FlossFunding::Configuration]
    attr_reader :config

    # Initialize a new Library record.
    #
    # @param namespace [FlossFunding::Namespace]
    # @param base_name [String]
    # @param including_path [String, nil]
    # @param env_var_name [String]
    # @param options [Hash]
    # @option options [Boolean, #call] :silent (nil)
    # @option options [String] :custom_namespace (nil)
    # @option options [String, nil] :config_path explicit config path; bypasses directory-walk search
    def initialize(namespace, custom_namespace, base_name, including_path, env_var_name, options = {})
      @namespace = namespace.name
      @base_name = base_name
      @including_path = including_path
      @env_var_name = env_var_name
      @silence = options[:silent]
      @custom_namespace = custom_namespace

      discover_roots_and_config!(including_path, options)

      @gem_name = derive_gem_name
      @config = load_config

      @seen_at = Time.now
      freeze
    end

    private

    # Determine the project (consumer) root and the library (producer) root.
    # - project_root_path: inferred from current working directory via ConfigFinder
    # - library_root_path: walk up from including_path to nearest Gemfile/gems.rb/*.gemspec
    def discover_roots_and_config!(including_path, options)
      explicit_cfg = options[:config_path]

      # Determine the project root, starting with Dir.pwd
      @project_root_path = ::FlossFunding::ProjectRoot.path

      if including_path.nil?
        # When including_path is nil, do not attempt to discover the library root
        # and bypass directory-walk searching for configs.
        @library_root_path = nil
        @config_path = explicit_cfg # may be nil; when nil, defaults will be used
        return
      end

      # Find the library root first (closest ancestor to activator)
      @library_root_path = ::FlossFunding::LibraryRoot.discover(including_path)

      # Resolve configuration path
      if explicit_cfg
        @config_path = explicit_cfg
      else
        start_dir = File.dirname(including_path) || @project_root_path || Dir.pwd
        @config_path = ::FlossFunding::ConfigFinder.find_config_path(start_dir)
      end
    end

    def load_config
      yaml_cfg = {}
      if @config_path && File.file?(@config_path)
        yaml_cfg = self.class.load_yaml_config(@config_path)
      end
      # Load defaults from config/default.yml and normalize values to arrays
      default_cfg = ::FlossFunding::ConfigLoader.default_configuration

      merged = {}
      # ensure all keys present and arrays
      (default_cfg.keys | yaml_cfg.keys).each do |k|
        merged[k] = normalize_to_array(yaml_cfg.key?(k) ? yaml_cfg[k] : default_cfg[k])
      end
      # augment with derived fields
      merged["gem_name"] = normalize_to_array(@gem_name)
      merged["silent"] = normalize_to_array(@silence) if defined?(@silence)

      ::FlossFunding::Configuration.new(merged)
    end

    def normalize_to_array(value)
      return [] if value.nil?
      return value.compact if value.is_a?(Array)
      [value]
    end

    def derive_gem_name
      # Prefer gemspec from library root
      if @library_root_path
        gemspec = Dir.glob(File.join(@library_root_path, "*.gemspec")).first
        if gemspec
          name = self.class.gem_name_for(gemspec)
          return name if name && !name.empty?
        end
      end
      # fallbacks
      return File.basename(@library_root_path) if @library_root_path
      @namespace
    end
  end
end
