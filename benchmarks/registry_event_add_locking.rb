# frozen_string_literal: true

# Microbenchmark: Registry event add under load
# Compare current single-lock path vs a naive dup/mutate/assign pattern
# Run via: rake bench or: ruby -Ilib benchmarks/registry_event_add_locking.rb

require "benchmark"
require "floss_funding"
require "floss_funding/activation_event"
require "floss_funding/namespace"
# Provide activation_occurrences helper (moved to spec/support)
require_relative "../spec/support/activation_occurrences_helper"

NAMESPACES = (ENV["NAMES"] || "200").to_i
EVENTS_PER_NS = (ENV["EVENTS"] || "5").to_i

FakeLibrary = Struct.new(:config)
FAKE_LIB = FakeLibrary.new(nil)

# Build deterministic list of namespace names
names = Array.new(NAMESPACES) { |i| format("BenchNS%04d", i + 1) }

# Helper to clear registry between runs
clear_registry = lambda do
  FlossFunding.namespaces = {}
end

current_impl = lambda do
  clear_registry.call
  names.each do |ns_name|
    ns = FlossFunding::Namespace.new(ns_name)
    EVENTS_PER_NS.times do
      ev = FlossFunding::ActivationEvent.new(FAKE_LIB, "", FlossFunding::DEFAULT_STATE, nil)

      # Use the public API to ensure parity with production code
      FlossFunding.add_or_update_namespace_with_event(ns, ev)
    end
  end
end

naive_impl = lambda do
  clear_registry.call
  names.each do |ns_name|
    ns = FlossFunding::Namespace.new(ns_name)
    EVENTS_PER_NS.times do
      ev = FlossFunding::ActivationEvent.new(FAKE_LIB, "", FlossFunding::DEFAULT_STATE, nil)
      # Simulate higher lock churn: read dup, mutate, write back
      current = FlossFunding.namespaces
      obj = current[ns.name] || ns
      obj.activation_events << ev
      current[ns.name] = obj
      FlossFunding.namespaces = current
    end
  end
end

puts "== Registry event add under load: current vs naive (names=#{NAMESPACES}, events/ns=#{EVENTS_PER_NS}) =="

t1 = Benchmark.realtime { current_impl.call }

# Sanity: ensure total events count matches
expected = NAMESPACES * EVENTS_PER_NS
actual = FlossFunding.activation_occurrences.length
puts format("Sanity current: occurrences=%d (expected=%d)", actual, expected)

# Run naive pattern
clear_registry.call

t2 = Benchmark.realtime { naive_impl.call }

actual2 = FlossFunding.activation_occurrences.length
puts format("Sanity naive  : occurrences=%d (expected=%d)", actual2, expected)

puts format("Current(single lock): %.6fs\nNaive(dup+assign)   : %.6fs\nOverhead factor     : %.2fx", t1, t2, (t1.zero? ? 0.0 : t2 / t1))
