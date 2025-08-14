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
    def initialize(library, activation_key, state = DEFAULT_STATE, silent = nil)
      @library = library
      @activation_key = activation_key
      @state = normalize_state(state.to_s)
      # Always use the deterministic time source from FlossFunding
      @occurred_at = ::FlossFunding.now_time
      @silent = silent
    end

    private

    # @param value [String]
    # @return [String]
    def normalize_state(value)
      return value if STATES.value?(value)

      DEFAULT_STATE
    end
  end
end
