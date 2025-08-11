# frozen_string_literal: true

module FlossFunding
  # Represents a single funding-related activation event for a Library.
  # Tracks mutable state across: "activated", "unactivated", and "invalid".
  class ActivationEvent
    STATE_VALUES = {
      :activated => 'activated',
      :unactivated => 'unactivated',
      :invalid => 'invalid',
    }.freeze

    # Default state is unknown/unactivated at creation time.
    DEFAULT_STATE = STATE_VALUES[:unactivated]

    # @return [FlossFunding::Library]
    attr_reader :library
    # @return [String] one of STATE_VALUES
    attr_accessor :state
    # @return [Time]
    attr_reader :occurred_at

    # @param library [FlossFunding::Library]
    # @param state [Symbol, String] initial state (defaults to :unactivated)
    # @param occurred_at [Time] timestamp (defaults to Time.now)
    def initialize(library, state = DEFAULT_STATE, occurred_at = Time.now)
      @library = library
      @state = normalize_state(state)
      @occurred_at = occurred_at
    end

    private

    def normalize_state(value)
      return value if STATE_VALUES.value?(value)
      if value.is_a?(Symbol) && STATE_VALUES.key?(value)
        return STATE_VALUES[value]
      end
      DEFAULT_STATE
    end
  end
end