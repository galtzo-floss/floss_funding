# frozen_string_literal: true

# Loader for 100 reusable benchmark fixture gems that exist on disk under
# spec/fixtures/bench_gems/bench_gem_XX with minimal gem structure.
#
# Each gem folder contains:
#   - Gemfile
#   - bench_gem_XX.gemspec
#   - .floss_funding.yml
#   - lib/bench_gem_XX.rb (defines BenchGemXX::Core or shared BenchGemShared::Core and conditionally includes Poke)
#
# ENV segmentation for conditional Poke inclusion (implemented inside each gem's lib file):
#   - FLOSS_FUNDING_FIXTURE_GROUP_1 .. FLOSS_FUNDING_FIXTURE_GROUP_10 control gems 01..90 (9 per group)
#   - FLOSS_FUNDING_FIXTURE_FINAL_10 controls gems 91..100 (shared namespace)

base_dir = File.expand_path("bench_gems", __dir__)

(1..100).each do |i|
  dir = format("bench_gem_%02d", i)
  lib_file = File.join(base_dir, dir, "lib", format("bench_gem_%02d.rb", i))
  # Use load (not require) to allow reloading across tests when ENV changes
  load(lib_file) if File.exist?(lib_file)
end
