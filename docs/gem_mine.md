# GemMine

Generic, caller-driven gem scaffold generator for benchmarking and test fixtures.

One-liner usage
- Generate N gems with sensible defaults under spec/fixtures/gem_mine:

  GemMine.factory(count: 30)

- Include floss_funding availability in templates and add a YAML file:

  GemMine.factory(
    count: 10,
    include_floss_funding: true,
    dependencies: [ { name: "floss_funding", path: "../../../.." } ],
    yaml_templates: {
      "gem_settings.yml" => <<~YML
        enabled: <%= helpers.env_enabled?(env_group_var) %>
        namespace: <%= namespace || module_name %>
      YML
    }
  )

Progress bar (optional)
- Show progress during generation (requires ruby-progressbar):

  GemMine.factory(
    count: 100,
    include_floss_funding: true,
    dependencies: [ { name: "floss_funding", path: "../../../.." } ],
    progress_bar: { title: "GemMine", format: "%t: |%B| %c/%C", autofinish: true }
  )

Principles
- Generic by default: GemMine encodes no project-specific namespace or activation logic.
- Templated content: Callers supply ERB-templated YAML and Ruby content; GemMine renders per-gem using a rich context.
- Dependencies: Accepts a generic dependencies array (supports :path, :git, versions, require).
- Grouping ENV: Exposes group metadata via env_group_var = "GEM_MINE_GROUP_#{group_index}" (0-based).

Factory API (GemMine.factory)
- All options may be static values or callables (Proc/Lambda) that receive a per-gem context hash.

Options (defaults in parentheses)
- count: Integer (100)
- root_dir: String ("spec/fixtures/gem_mine")
- gem_name_prefix: String ("bench_gem_")
- start_index: Integer (1)
- group_size: Integer (10)
- groups_env_prefix: String ("GEM_MINE_GROUP_")
- namespace_proc: Proc(ctx)->String or nil (nil)
- include_floss_funding: Boolean (false)
- dependencies: Array<Hash> or Proc(ctx)->Array<Hash> ([])
  - Keys supported: name (required), version (String or Array), require, path, git, branch, ref, tag, platforms
- authors: Array<String> or Proc(ctx)->Array<String> ([])
- version_strategy: Proc(ctx)->String ("0.0.#{index}")
- gemspec_extras: Hash or Proc(ctx)->Hash ({})
  - Common keys: summary, description, metadata, licenses, files_glob (default "lib/**/*.rb"), require_paths (default ["lib"])
- yaml_templates: Hash or Proc(ctx)->Hash ({})
  - Keys match /(.*)(_ya?ml)/ or end with .yml/.yaml, value is ERB text; output becomes <basename>.yml or .yaml
- file_contents: Hash or Proc(ctx)->Hash (nil => generate a minimal default lib file)
  - Map relative paths (e.g., "lib/<gem_name>.rb") to ERB content
- overwrite: Boolean (true)
- cleanup: Boolean (false) – remove root_dir before generation
- seed: Integer or nil (nil)
- after_generate: Proc(result:, gem:) – per-gem hook
- progress_bar: Hash or nil (nil) – symbol-keyed options forwarded to ProgressBar.create; when provided, a progress bar will show gem generation progress. The :total option defaults to count when omitted.

ERB context keys
- index, ordinal, count
- group_size, group_index (0-based), groups_env_prefix
- env_group_var (e.g., GEM_MINE_GROUP_0)
- root_dir, gem_dir, lib_dir
- gem_name (e.g., bench_gem_01), module_name (e.g., BenchGem01)
- namespace (from namespace_proc or nil)
- include_floss_funding (Boolean)
- dependencies (normalized per gem)
- helpers (GemMine::Helpers)

Helpers
- helpers.poke_include(ns): Ruby snippet that requires "floss_funding" and includes FlossFunding::Poke into ns::Core.
- helpers.env_enabled?(var): Ruby expression string for ENV check (ENV.fetch(var, "0") != "0").
- helpers.camelize(str) / helpers.underscore(str): Naming utilities.

Default files generated per gem
- Gemfile: rubygems source + dependencies + gemspec line
- <gem_name>.gemspec: basic gemspec with authors/version/files; adds runtime dependencies
- YAML files: from yaml_templates
- lib/<gem_name>.rb (if file_contents not provided):
  - Defines module <ModuleName> and submodule Core
  - If ENV.fetch(env_group_var, "0") != "0" and include_floss_funding is true, inserts helpers.poke_include(namespace || module_name)

Notes
- To toggle groups during experiments, set GEM_MINE_GROUP_0..9 to "1" or "0".
- Use namespace_proc and templates to encode any project-specific behavior (shared namespaces, Poke inclusion, etc.).
