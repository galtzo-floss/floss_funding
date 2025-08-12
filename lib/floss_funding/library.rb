# frozen_string_literal: true

require 'yaml'
require 'rubygems'
require 'floss_funding/config_finder'
require 'floss_funding/file_finder'

module FlossFunding
  # Represents a single Library (a gem/namespace pair) that has included
  # FlossFunding::Poke. Holds discovery info, configuration, and env details.
  class Library
    # @return [String]
    attr_reader :namespace
    # @return [String]
    attr_reader :gem_name
    # @return [String]
    attr_reader :env_var_name
    # @return [String]
    attr_reader :activation_key
    # @return [String]
    attr_reader :including_path
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
    # @return [Hash{String=>Array}]
    attr_reader :config

    # Initialize a new Library record.
    #
    # @param namespace [String]
    # @param including_path [String]
    # @param options [Hash]
    # @option options [Boolean, #call] :silent (nil)
    # @option options [String] :custom_namespace (nil)
    def initialize(namespace, including_path, options = {})
      @namespace = namespace
      @including_path = including_path
      @env_var_name = ::FlossFunding::UnderBar.env_variable_name(namespace)
      @activation_key = ENV.fetch(@env_var_name, "")
      @silence = options[:silent]
      custom_namespace = options[:custom_namespace]
      @custom_namespace = custom_namespace if custom_namespace && !custom_namespace.empty?

      discover_roots!(including_path)

      @config = load_config
      @gem_name = derive_gem_name

      @seen_at = Time.now
      freeze
    end

    private

    # Determine the project (consumer) root and the library (producer) root.
    # - project_root_path: inferred from current working directory via ConfigFinder
    # - library_root_path: walk up from including_path to nearest Gemfile/gems.rb/*.gemspec
    def discover_roots!(including_path)
      # Find the library root first,
      #   as it will be the closest ancestor to the FlossFunding activator.
      start_dir = File.expand_path(File.dirname(including_path))
      # Find nearest .floss_funding.yml/Gemfile/gems.rb/*.gemspec upwards from including file
      candidates = [
        find_last_upwards('Gemfile', start_dir),
        find_last_upwards('gems.rb', start_dir),
        find_last_upwards('*.gemspec', start_dir),
      ].compact
      @library_root_path = File.dirname(candidates.first) unless candidates.empty?
      # @project_start_dir = File.dirname(@library_root_path) if @library_root_path

      # Determine the project root, starting with Dir.pwd
      @project_root_path = ::FlossFunding::ConfigFinder.project_root

      # config path is found with respect to the project root (consumer)
      target = @project_root_path || Dir.pwd
      @config_path = ::FlossFunding::ConfigFinder.find_config_path(target)
    end

    def find_last_upwards(pattern, start_dir)
      last = nil
      Pathname.new(start_dir).expand_path.ascend do |dir|
        file = dir + pattern
        if file.exist?
          last = file.to_s
        end
        break if ::FlossFunding::FileFinder.root_level?(dir, nil)
      end
      last
    end

    def load_config
      default_cfg = ::FlossFunding::Config::DEFAULT_CONFIG.transform_values { |v| v.dup }
      yaml_cfg = {}
      begin
        if @config_path && File.file?(@config_path)
          yaml_cfg = YAML.safe_load(File.read(@config_path)) || {}
        end
      rescue StandardError
        yaml_cfg = {}
      end
      merged = {}
      # ensure all keys present and arrays
      (default_cfg.keys | yaml_cfg.keys).each do |k|
        merged[k] = normalize_to_array(yaml_cfg.key?(k) ? yaml_cfg[k] : default_cfg[k])
      end
      merged
    end

    def normalize_to_array(value)
      return [] if value.nil?
      return value.compact if value.is_a?(Array)
      [value]
    end

    def derive_gem_name
      # Prefer gemspec from library root
      if @library_root_path
        gemspec = Dir.glob(File.join(@library_root_path, '*.gemspec')).first
        if gemspec
          begin
            spec = Gem::Specification.load(gemspec)
            return spec.name if spec && spec.name
          rescue StandardError
            # ignore
          end
        end
      end
      # fallbacks
      return File.basename(@library_root_path) if @library_root_path
      @namespace
    end
  end
end
