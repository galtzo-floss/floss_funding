# frozen_string_literal: true

# Microbenchmark: LibraryRoot.discover cold (no cache) vs warm (cached)
# Run via: rake bench or: ruby -Ilib benchmarks/library_root_discover_cache.rb

require "benchmark"
require "floss_funding/library_root"

files = Dir[File.expand_path("../lib/**/*.rb", __dir__)]
# Limit to a representative subset to keep runtime reasonable
files = files.first(50)

ITER = (ENV["ITER"] || "500").to_i

puts "== LibraryRoot.discover: cold vs warm (#{ITER}x over #{files.size} files) =="

# Cold: reset cache each iteration and discover for each file
cold = Benchmark.realtime do
  ITER.times do
    FlossFunding::LibraryRoot.reset_cache!
    files.each { |f| FlossFunding::LibraryRoot.discover(f) }
  end
end

# Warm: prime once then hit cache
FlossFunding::LibraryRoot.reset_cache!
files.each { |f| FlossFunding::LibraryRoot.discover(f) }

warm = Benchmark.realtime do
  ITER.times do
    files.each { |f| FlossFunding::LibraryRoot.discover(f) }
  end
end

puts format("Cold (reset each iter): %.6fs\nWarm (cached)       : %.6fs\nSpeedup             : %.2fx", cold, warm, (warm.zero? ? 0.0 : cold / warm))
