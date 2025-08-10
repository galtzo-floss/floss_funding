# frozen_string_literal: true

# Loader for 10 reusable non-gem fixtures located under spec/fixtures/non_gems
# These are split into two groups:
# - Bundler non-gems (Gemfile present, no gemspec): ng_bundler_1..5
# - Plain non-gems (no Gemfile/gemspec): ng_plain_1..5
# Each defines <Namespace>::Core, and conditionally includes FlossFunding::Poke
# based on an ENV enabler variable per fixture.

base_dir = File.expand_path("non_gems", __dir__)

bundler = (1..5).map { |i| ["ng_bundler_#{i}", "lib/ng_bundler_#{i}.rb"] }
plain = (1..5).map { |i| ["ng_plain_#{i}", "lib/ng_plain_#{i}.rb"] }

(bundler + plain).each do |dir, lib_rel|
  lib_file = File.join(base_dir, dir, lib_rel)
  load(lib_file) if File.exist?(lib_file)
end
