# frozen_string_literal: true

# Loader for 51 reusable benchmark fixture gems that exist on disk under
# spec/fixtures/bench_gems/bench_gem_XX with minimal gem structure.
#
# Each gem folder contains:
#   - Gemfile
#   - bench_gem_XX.gemspec
#   - .floss_funding.yml
#   - lib/bench_gem_XX.rb (defines BenchGemXX::Core and conditionally includes Poke)
#
# ENV segmentation for conditional Poke inclusion (implemented inside each gem's lib file):
#   FLOSS_FUNDING_FIXTURE_GROUP_1 .. FLOSS_FUNDING_FIXTURE_GROUP_10
# Group 1 controls gems 01..05, group 2 controls 06..10, ..., group 10 controls 46..50.
# Exactly 50 gems are managed by the 10 segmented ENV variables.

base_dir = File.expand_path("bench_gems", __dir__)

(1..50).each do |i|
  dir = format("bench_gem_%02d", i)
  lib_file = File.join(base_dir, dir, "lib", format("bench_gem_%02d.rb", i))
  # Use load (not require) to allow reloading across tests when ENV changes
  load(lib_file) if File.exist?(lib_file)
end
