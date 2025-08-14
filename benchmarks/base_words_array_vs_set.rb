# frozen_string_literal: true

# Microbenchmark: Base words membership lookup Array#include? vs Set#include?
# Run via: rake bench or: ruby -Ilib benchmarks/base_words_array_vs_set.rb

require "benchmark"
require "set"
require "floss_funding"

ITER = (ENV["ITER"] || "5000").to_i

all_words = begin
  File.readlines(FlossFunding::BASE_WORDS_PATH, :chomp => true)
rescue StandardError
  []
end

# NOTE: There are only 2400 base words in the gem, so no reason to test larger sizes.
sizes = [100, 500, 1_000, 2_400].select { |n| n <= all_words.length }
if sizes.empty?
  sizes = [all_words.length]
end

puts "== Base words membership: Array#bsearch? vs Set#include? (#{ITER}x per size) =="

sizes.each do |n|
  slice = all_words[0, n]
  target = slice[n / 2]

  array_time = Benchmark.realtime do
    ITER.times { slice.bsearch { |i| i == target } }
  end

  set = Set.new(slice)
  set_time = Benchmark.realtime do
    ITER.times { set.include?(target) }
  end

  ratio = set_time.zero? ? 0.0 : array_time / set_time
  puts format("N=%7d  Array#include?: %.6fs  Set#include?: %.6fs  Speedup(Set): %.2fx", n, array_time, set_time, ratio)
end
