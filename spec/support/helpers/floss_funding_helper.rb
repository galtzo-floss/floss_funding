# frozen_string_literal: true

# Test/benchmark-only helper: FlossFunding
#
# This method used to live in the runtime library. It is only needed
# for specs and micro-benchmarks to easily count total activation events
# across namespaces, so we provide it here under spec/support.
#
# It reopens FlossFunding to add a convenience reader that flattens the
# activation event counts per namespace into an array of namespace names.
#
# Note: This file is auto-required by spec_helper (via spec/support/**/*).
# For benchmarks or ad-hoc scripts, require it explicitly.
#
# rubocop:disable ThreadSafety/ClassInstanceVariable
module FlossFunding
  class << self
    # Provides access to the mutex for thread synchronization
    attr_reader :mutex

    # Read the serialized month (Integer) in which the runtime was loaded
    #
    # Only used in specs. Runtime code only uses the class instance variable.
    #
    # when FlossFunding.loaded_at has been set via spec/support/spec_only_writers,
    # this method derives the month from that deterministic time source to keep behavior predictable.
    # Alternatively, specs may set loaded_month directly via the spec-only writer to fully override.
    #
    # @see @loaded_at
    #
    # @return [Integer]
    def loaded_month
      # If a spec has provided a deterministic time source, derive from it.
      la = loaded_at
      return @loaded_month = Month.new(la.year, la.month).to_i if la

      # Otherwise, use the value captured at load time (or explicitly overridden via the writer).
      @loaded_month
    end

    # Return an array of namespace strings for each activation event occurrence (pokes)
    # e.g., ["Ns1", "Ns1", "Ns2"] if Ns1 had 2 events and Ns2 had 1
    # @return [Array<String>]
    def activation_occurrences
      mutex.synchronize do
        arr = []
        @namespaces.each do |ns, nobj|
          count = nobj.activation_events.length
          count.times { arr << ns } if count > 0
        end
        arr
      end
    end
  end
end
# rubocop:enable ThreadSafety/ClassInstanceVariable
