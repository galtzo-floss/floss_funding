# FlossFunding Performance Review (lib/floss_funding)

Date: 2025-08-13
Scope: Focused, non-invasive performance review of the code under lib/floss_funding. No behavior changes were made; this document proposes improvements and asks one question per suggestion to confirm intent and acceptable trade-offs.

Summary of hotspots identified
- File/IO and YAML parsing
  - Repeated parsing of config YAML (default and per-project) and repeated filesystem walks for discovery.
  - Gem name derivation uses Dir.glob + Gem::Specification.load per inclusion.
  - Base words file re-read per activation check.
- Crypto and hashing
  - OpenSSL::Cipher.new and Digest::MD5.hexdigest(name) created/calculated per decryption.
- Data structures and synchronization
  - Namespaces registry incurs extra allocations (dup + replace) around a mutex.
  - Recomputed derived collections (names, env var names, occurrences) on demand.
- String/Array work
  - Underscore conversion via regex/gsub; config normalization with repeated small array allocations.

Suggestions and questions

1) Cache default configuration (YAML) once per process
- Where: lib/floss_funding/config_loader.rb: default_configuration
- Today: Reads and parses config/config.yml for every call: YAML.safe_load(File.read(DEFAULT_FILE)).
- Idea: Memoize in a class ivar and return a frozen hash to avoid re-parsing.
  - Example:
    - def default_configuration; @default_configuration ||= load_file(DEFAULT_FILE).freeze; end
- Expected impact: Avoids repeated disk IO and parsing when multiple libraries/namespaces are processed.
- Question: Is the default config file expected to change during the process lifetime (e.g., hot reload/dev mode)? If not, can we safely memoize it for the life of the process?
- Answer: It will not change; memoize it for the process lifetime.

2) Cache per-path project configuration loads
- Where: lib/floss_funding/library.rb: load_config uses @config_path and YAML.safe_load(File.read(@config_path)).
- Idea: Maintain a small process cache keyed by absolute @config_path with optional mtime-based invalidation.
  - Example: CONFIG_CACHE[path] = { mtime:, data: } and reuse when unchanged.
- Expected impact: Eliminates repeated disk reads/parsing when multiple inclusions share the same config file.
- Question: Should a change to .floss_funding.yml be picked up automatically at runtime (live reload), or is it acceptable to cache for the process duration?
- Answer: It will not change; cache for the process lifetime.

3) Cache gemspec name lookup
- Where: lib/floss_funding/library.rb: derive_gem_name uses Dir.glob + Gem::Specification.load.
- Idea: Cache mapping from gemspec path to gem name; skip Gem::Specification.load on repeated calls.
- Expected impact: Significant for repeated inclusions in monorepos or in test suites.
- Question: Do you anticipate gemspec contents (especially name) changing during a single process? If not, can we cache this for the process lifetime?
- Answer: It will not change; cache, but only the specific attributes of the gemspec we are interested in, for the process lifetime.

4) Base words: load once and reuse; switch to Set membership for checks
- Where: lib/floss_funding.rb: base_words, check_activation
- Today: base_words opens and reads N lines from the file on each call; check_activation builds an Array then uses bsearch (with a boolean equality block) or include?. The boolean form of bsearch with equality does not preserve monotonicity and may be unpredictable.
- Ideas:
  - Read base.txt once at first use into an Array (all lines), freeze it; serve slices via base_words by returning array[0, n].
  - Maintain a Set of the active slice for O(1) lookups (per month window or per n).
  - Replace bsearch usage with set.include?(plain_text) or array.include? if Set is not used.
- Expected impact: Removes repeated IO and speeds up repeated check_activation calls.
- Question: Is it acceptable to increase memory usage to keep the base words array/set resident for the life of the process? If memory is a concern, would a per-month Set (recomputed at month change) be acceptable?
- Answer: Yes, but it is not necessary to recompute for month change. The relevant time does not change, as this is the purpose of `FlossFunding.now_time`. Does this change the question?

5) Memoize namespace-derived MD5 key
- Where: lib/floss_funding/namespace.rb: floss_funding_decrypt
- Today: Digest::MD5.hexdigest(name) is computed per call; OpenSSL::Cipher.new is created per call.
- Idea: Cache the MD5 hexdigest once per Namespace instance (e.g., @key_digest) and reuse; leave the Cipher as per-call (OpenSSL::Cipher objects are stateful and not easily reusable safely).
- Expected impact: Reduces hashing overhead for repeated decrypts.
- Question: Is a Namespace instance reused across multiple decrypt operations in your expected usage pattern? If yes, we can memoize @key_digest safely; confirm no cross-namespace key changes are expected.
- In a single runtime process the Namespace will be reused when libraries share a custom namespace, which some groups of gems will do. Go ahead and cache the key digest.

6) UnderBar.env_variable_name memoization
- Where: lib/floss_funding/under_bar.rb
- Today: Splits and transforms on each call; may be called frequently when inspecting many namespaces or building maps.
- Idea: Add a small in-process cache keyed by the input string; values are frozen strings. Clear cache only if the prefix changes.
- Consideration: Constants::DEFAULT_PREFIX is read at require-time from ENV; unless you plan to change ENV['FLOSS_FUNDING_ENV_PREFIX'] mid-process and re-require constants.rb, the prefix is effectively stable.
- Expected impact: Minor but cheap; reduces repeat work in env_var_names and elsewhere.
- Question: Should we support dynamic changes to ENV['FLOSS_FUNDING_ENV_PREFIX'] after FlossFunding has been required? If not, we can safely memoize.
- No dynamic changes, please memoize.

7) Namespaces registry: reduce allocations and lock churn
- Where: lib/floss_funding.rb: add_or_update_namespace_with_event, namespaces, and related getters.
- Today: add_or_update_namespace_with_event reads a dup of the registry (namespaces), mutates a local copy, then reassigns via namespaces=, all while acquiring the mutex multiple times; namespaces accessor returns a dup every time.
- Ideas:
  - Use a single mutex.synchronize block to mutate @namespaces in-place and update a Namespace’s activation_events (using << instead of array concatenation to avoid a new array).
  - Return a frozen snapshot (or iterators) instead of duping on every read, or document that callers must not mutate (freeze nested values if needed).
- Expected impact: Lower object churn and fewer mutex operations during event recording and registry reads.
- Question: Do you require the public getter to return a deep copy for safety? If so, would returning a frozen shallow copy (and freezing nested arrays) meet your requirements while lowering allocations?
- Yes, please go ahead with these suggestions to lower allocations and mutex lock churn.

8) Precompute derived collections or maintain counters
- Where: lib/floss_funding.rb: activated_namespace_names, unactivated_namespace_names, invalid_namespace_names, activation_occurrences.
- Today: Recompute via select/map/flat_map under the mutex.
- Ideas:
  - Maintain per-namespace cached booleans/counters when adding events to quickly answer queries without scanning all namespaces each time.
  - Alternatively, keep as-is but document that they are O(N) operations; add micro-optimizations like using .each_with_object and avoiding nested allocations where possible.
- Expected impact: Improves performance when these queries are frequent and namespace count is large.
- Question: Are these methods called in hot paths (e.g., at_exit only vs runtime UI)? If they are cold, we can leave as-is; if hot, we can add counters.
- These are cold paths, only called at exit. Document that they are O(N) operations on cold paths, and add the micro optimizations.

9) ConfigFinder/FileFinder: memoize ascents
- Where: lib/floss_funding/config_finder.rb and file_finder.rb
- Today: Path ascents run per call; project_root is cached, but find_config_path and project_root_for (for a start_dir) are not memoized.
- Idea: Add small caches keyed by start_dir for find_config_path and project_root_for results. Consider invalidation on directory changes only if needed.
- Expected impact: Reduces filesystem stats when multiple inclusions originate from nearby directories.
- Question: Do you expect the filesystem structure (Gemfile, *.gemspec, dotfiles) to change during process runtime? If not, can we cache lookups for the life of the process?
- Expect filesystem to not change during process runtime, so cache anything that would be re-used for the process lifetime, and invalidation is not needed.

10) LibraryRoot.discover: avoid triple ascent passes
- Where: lib/floss_funding/library_root.rb: discover
- Today: Calls find_file_upwards three times separately for Gemfile, gems.rb, *.gemspec and then compacts; that’s up to 3 ascents.
- Idea: Create a helper that ascends once and checks for any of the 3 signals at each level to return the first match, or memoize results per including_path directory.
- Expected impact: Cuts redundant ascents by ~3x in worst-case paths.
- Question: Would a per-directory cache (dir -> discovered root) be acceptable, or do you prefer a single-pass finder without caching?
- Per-directory cache is acceptable. Also only ascend once per directory to look for the three files, via the suggested helper.

11) Minor: Array/Hash normalization
- Where: Configuration#initialize, Library#load_config, Configuration.merged_config
- Ideas:
  - Avoid repeated k.to_s conversions by pre-normalizing keys
  - Prefer in-place concat (<< and push) where safe
  - Freeze deeply only once when publishing objects externally
- Expected impact: Small but consistent allocation savings.
- Question: Are we OK to freeze more objects (e.g., arrays in configs) to guard against accidental external mutation while enabling lower allocation patterns?
- Yes.

12) Minor: replace boolean bsearch with include?
- Where: lib/floss_funding.rb: check_activation (if not adopting Set as in #4)
- Today: words.bsearch { |word| plain_text == word } violates the monotonic predicate required by bsearch (boolean form). Could be slower and potentially incorrect.
- Idea: Use include? or index; or use bsearch_index with proper comparator if words are sorted and a strict comparator is available.
- Expected impact: Predictable and simpler behavior; possibly faster for small N.
- Question: Are the base words guaranteed to be sorted? If yes, we can use bsearch_index with a proper comparator; otherwise prefer a Set as in #4.
- Base words are guaranteed to be sorted.

13) Poke/Inclusion: reduce FS work on contraindicated paths
- Where: lib/floss_funding/poke.rb and inclusion.rb
- Today: Poke.new does ContraIndications checks early; Inclusion does LibraryRoot.discover and ConfigFinder lookups even when :silent is a callable (defers to at_exit), but the check is already in Poke.new.
- Idea: No change necessary, but if additional contraindications are added, keep them as early as possible to short-circuit before FS operations.
- Question: Any further contraindications you want to add (e.g., specific environments) that could skip discovery earlier?
- Add a contraindication for non-TTY environments. Only proceed with complete Poke.new if TTY.

14) Optional: avoid Gem::Specification.load when only name is needed
- Where: lib/floss_funding/library.rb: derive_gem_name
- Idea: Parse first name from .gemspec source via a lightweight regexp when load is too slow, guarded behind a fallback to Gem::Specification.load for correctness.
- Expected impact: Shaves off RubyGems overhead when repeatedly deriving names; more brittle than #3 caching.
- Question: Would you consider a lightweight .gemspec parse for the common case, or do you prefer strictly using RubyGems APIs with caching only?
- Yes, prefer a lightweight parse, and on parse failure fallback to Gem::Specification.load for correctness.

Benchmarking aids (optional follow-ups)
- Add minimal microbench specs or script (benchmarks/), e.g., measuring:
  - Config default load vs memoized
  - Base words lookup per N with Array#include? vs Set#include?
  - LibraryRoot.discover with and without single-pass/cache
  - Registry event add under load with current vs proposed locking
- These would be behind a dev-only rake task and not run in CI by default.
Yes, add these benchmarking aids.

Notes
- All proposals are backward-compatible behavior-wise; most are memoization/caching and micro-alloc optimizations.
- Where caches are introduced, we propose clear! methods for tests and document cache lifetimes.
- Thread-safety: Registry mutations must remain under a single mutex.

Please review the questions inline to confirm intent; I will implement the agreed changes with tests.


## Running microbenchmarks (dev-only)

These benchmarks are optional aids and are not part of CI or the default Rake tasks.

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
