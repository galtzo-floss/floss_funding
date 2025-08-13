# frozen_string_literal: true

# Microbenchmark: Config default load (cold) vs memoized (warm)
# Run via: rake bench or: ruby -Ilib benchmarks/config_default_load_vs_memoized.rb

require "benchmark"
require "floss_funding"

ITERATIONS = (ENV["ITER"] || "200").to_i

puts "== ConfigLoader.default_configuration: cold vs warm (#{ITERATIONS}x) =="

# Cold loads: reset cache every time to force YAML read/parse
cold = Benchmark.realtime do
  ITERATIONS.times do
    FlossFunding::ConfigLoader.reset_caches!
    FlossFunding::ConfigLoader.default_configuration
  end
end

# Warm loads: prime once, then repeatedly fetch memoized value
FlossFunding::ConfigLoader.reset_caches!
FlossFunding::ConfigLoader.default_configuration
warm = Benchmark.realtime do
  ITERATIONS.times do
    FlossFunding::ConfigLoader.default_configuration
  end
end

puts format("Cold (reset each time): %.6fs\nWarm (memoized)     : %.6fs\nSpeedup             : %.2fx", cold, warm, (warm.zero? ? 0.0 : cold / warm))
