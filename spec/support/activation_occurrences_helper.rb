# frozen_string_literal: true

# Test/benchmark-only helper: activation_occurrences
#
# This method used to live in the production library. It is only needed
# for specs and micro-benchmarks to easily count total activation events
# across namespaces, so we provide it here under spec/support.
#
# It reopens FlossFunding to add a convenience reader that flattens the
# activation event counts per namespace into an array of namespace names.
#
# Note: This file is auto-required by spec_helper (via spec/support/**/*).
# For benchmarks or ad-hoc scripts, require it explicitly.
module FlossFunding
  class << self
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
