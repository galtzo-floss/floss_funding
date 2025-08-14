## Running microbenchmarks (dev-only)

The benchmarks in this directory are the "show-me" explanation for why specific patterns
were chosen over other, equally effective, but perhaps not as performant, ones.

- List available scripts:
    - rake bench:list
- Run all scripts (skips automatically on CI):
    - rake bench
- Run a single script directly:
    - ruby -Ilib benchmarks/<script_name>.rb

Available scripts under benchmarks/:
- config_default_load_vs_memoized.rb — Config default YAML load: cold vs memoized
- base_words_array_vs_set.rb — Base words lookup: Array#include? vs Set#include?
- library_root_discover_cache.rb — LibraryRoot.discover: cold vs cached
- registry_event_add_locking.rb — Registry event add: single-lock vs naive dup/mutate/assign

Tuning via env vars:
- ITER — iterations per script (varies by script; defaults are conservative)
- NAMES — namespaces count for registry_event_add_locking.rb (default: 200)
- EVENTS — events per namespace for registry_event_add_locking.rb (default: 5)

Notes:
- These scripts use Ruby's stdlib Benchmark.realtime and print simple summaries.
- They are designed for local exploration and will no-op when ENV["CI"] is true via the Rake task.
