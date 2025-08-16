# frozen_string_literal: true

require "yaml"
require "rubygems"
require "floss_funding/config_finder"
require "floss_funding/file_finder"
require "floss_funding/configuration"

module FlossFunding
  # Represents a single Library (a gem/namespace pair) that has included
  # FlossFunding::Poke. Holds discovery info, configuration, and env details.
  class Library
    include FileFinder

    # Namespace computed from base_name (including module's actual name), and custom_namespace
    # @return [String]
    attr_reader :namespace

    # including module's actual name
    # @return [String]
    attr_reader :base_name

    # @return [String]
    attr_reader :library_name
    # @return [String]
    attr_reader :including_path
    # @return [String]
    attr_reader :env_var_name
    # @return [String]
    attr_reader :library_root_path
    # @return [String]
    attr_reader :library_config_path
    # @return [Time]
    attr_reader :seen_at
    # @return [Object] may be boolean or callable as provided
    attr_reader :silence
    # @return [FlossFunding::Configuration]
    attr_reader :config

    # Convenience: gem_name used by CLI; alias to library_name for now
    def gem_name
      @library_name
    end

    # Initialize a new Library record.
    #
    # @param library_name [String]
    # @param ns [FlossFunding::Namespace]
    # @param custom_ns [String, nil]
    # @param base_name [String]
    # @param including_path [String]
    # @param root_path [String]
    # @param config_path [String]
    # @param env_var_name [String]
    # @param config [FlossFunding::Configuration]
    # @param silent [Boolean, #call]
    def initialize(library_name, ns, custom_ns, base_name, including_path, root_path, config_path, env_var_name, config, silent)
      @library_name = library_name
      @namespace = ns.name
      @base_name = base_name
      @including_path = including_path
      @env_var_name = env_var_name
      @silence = silent
      @custom_ns = custom_ns
      @library_root_path = root_path
      @library_config_path = config_path

      @config = config

      # In normal runtime we don't care about the @seen_at value, as this isn't an interactive library.
      # @seen_at is only useful for debugging; e.g., could be used to order libraries by time of discovery
      @seen_at = DEBUG ? Time.now : FlossFunding.loaded_at
      freeze
    end
  end
end
