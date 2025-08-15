# frozen_string_literal: true

module FlossFunding
  # Represents a single funding-related activation event for a Library.
  # Tracks mutable state across: "activated", "unactivated", and "invalid".
  class ActivationEvent
    # @return [FlossFunding::Library]
    attr_reader :library
    # @return [String]
    attr_reader :activation_key
    # @return [String] one of STATE_VALUES
    attr_accessor :state
    # @return [Time]
    attr_reader :occurred_at
    # @return [Object, nil] flag or callable indicating silent preference
    attr_reader :silent

    # @param library [FlossFunding::Library]
    # @param activation_key [String]
    # @param state [Symbol, String] initial state (defaults to :unactivated)
    # @param silent [Object, nil] optional silence flag or callable captured at event creation
    def initialize(library, activation_key, state, silent)
      @library = library
      @activation_key = activation_key
      @state = state # has already been normalized by FlossFunding::Inclusion
      # Always use the deterministic time source from FlossFunding
      @occurred_at = ::FlossFunding.loaded_at
      @silent = silent
      validate!
      freeze
    end

    def validate!
      raise FlossFunding::Error, "#{@state.inspect} (#{@state.class}) must be one of #{STATE_VALUES}" unless STATE_VALUES.include?(@state)
      raise FlossFunding::Error, "silent must be nil or respond to call (silent=true short circuits)" unless @silent.nil? || @silent.respond_to?(:call)
    end
  end
end
