# frozen_string_literal: true

module FlossFunding
  # Represents the runtime inclusion context for a given inclusion of FlossFunding.
  # Encapsulates discovery (Namespace, Library), activation state, and the
  # ActivationEvent generated from an include site.
  class Inclusion
    # @return [Module]
    attr_reader :base
    # @return [String]
    attr_reader :including_path
    # @return [String, nil]
    attr_reader :custom_namespace
    # @return [Object, nil]
    attr_reader :silent
    # @return [String]
    attr_reader :name
    # @return [FlossFunding::Namespace]
    attr_reader :namespace
    # @return [FlossFunding::Library]
    attr_reader :library
    # @return [String]
    attr_reader :activation_key
    # @return [String]
    attr_reader :state
    # @return [FlossFunding::ActivationEvent]
    attr_reader :event
    # return [FlossFunding::Persist]
    attr_reader :persist

    # Build an Inclusion and register its activation event.
    #
    # @param base [Module] the including module
    # @param custom_namespace [String, nil]
    # @param including_path [String]
    # @param silent_opt [Object, nil]
    def initialize(base, custom_namespace, including_path, silent_opt = nil)
      @base = base
      @including_path = including_path
      @custom_namespace = custom_namespace
      @silent = silent_opt

      validate_inputs!

      require "floss_funding/check"
      # Extend the base with the checker module first
      base.extend(::FlossFunding::Check)

      @name = if custom_namespace.is_a?(String) && !custom_namespace.empty?
        custom_namespace
      else
        base.name
      end

      @namespace = FlossFunding::Namespace.new(@name, base)

      @library = ::FlossFunding::Library.new(
        @namespace,
        base.name,
        including_path,
        :silent => silent_opt,
        :custom_namespace => custom_namespace,
        :env_var_name => @namespace.env_var_name,
      )

      @activation_key = @namespace.activation_key
      @state = @namespace.state

      @event = ::FlossFunding::ActivationEvent.new(
        @library,
        @activation_key,
        @state,
        ::FlossFunding::Check::ClassMethods.now_time,
        silent_opt,
      )

      FlossFunding.add_or_update_namespace_with_event(@namespace, @event)
    end

    private

    def validate_inputs!
      unless @including_path.is_a?(String)
        raise ::FlossFunding::Error, "including_path must be a String file path (e.g., __FILE__), got #{@including_path.class}"
      end
      unless @base.respond_to?(:name) && @base.name && @base.name.is_a?(String)
        raise ::FlossFunding::Error, "base must have a name (e.g., MyGemLibrary), got #{@base.inspect}"
      end
      unless @custom_namespace.nil? || @custom_namespace.is_a?(String) && !@custom_namespace.empty?
        raise ::FlossFunding::Error, "custom_namespace must be nil or a non-empty String (e.g., MyGemLibrary), got #{@custom_namespace.inspect}"
      end
    end
  end
end
