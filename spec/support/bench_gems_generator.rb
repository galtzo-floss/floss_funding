# frozen_string_literal: true

require "fileutils"

module FlossFunding
  module BenchGemsGenerator
    module_function

    def generate_all
      root = File.expand_path("../fixtures/bench_gems", __dir__)
      FileUtils.mkdir_p(root)
      (1..60).each do |i|
        generate_one(root, i)
      end
    end

    def generate_one(root, i)
      num = format("%02d", i)
      gem_dir = File.join(root, "bench_gem_#{num}")
      lib_dir = File.join(gem_dir, "lib")
      lib_file = File.join(lib_dir, "bench_gem_#{num}.rb")
      gemspec = File.join(gem_dir, "bench_gem_#{num}.gemspec")
      gemfile = File.join(gem_dir, "Gemfile")
      cfgfile = File.join(gem_dir, ".floss_funding.yml")

      FileUtils.mkdir_p(lib_dir)

      # Gemfile (always overwrite to ensure it targets local floss_funding)
      File.write(gemfile, <<-RUBY)
# frozen_string_literal: true
source "https://rubygems.org"

# Depend on the local floss_funding gem under test
gem "floss_funding", :path => "../../../.."

# Include this fixture gemspec
gemspec
      RUBY

      # Gemspec (always overwrite to ensure dependency on floss_funding)
      File.write(gemspec, <<-RUBY)
# frozen_string_literal: true
Gem::Specification.new do |s|
  s.name        = "bench_gem_#{num}"
  s.version     = "0.0.0"
  s.summary     = "Fixture gem for benchmarking"
  s.authors     = ["Fixture"]
  s.files       = Dir["lib/**/*.rb"]
  s.require_paths = ["lib"]

  # Ensure fixtures depend on the library under test
  s.add_dependency "floss_funding" # rubocop:disable Gemspec/DependencyVersion
end
      RUBY

      # Config
      unless File.exist?(cfgfile)
        File.write(cfgfile, <<-YAML)
# Minimal config for fixture gem #{num}
suggested_donation_amount: 5
        YAML
      end

      # lib/bench_gem_XX.rb (always overwrite to ensure correctness)
      File.write(lib_file, <<-'RUBY')
# frozen_string_literal: true

# Derive gem number from parent directory of lib (bench_gem_XX)
current_dir_name = File.basename(File.dirname(__dir__))
current_num = current_dir_name[-2, 2].to_i

# Namespace and ENV selection logic:
# - For gems 1..50: unique namespaces BenchGemXX, grouped by 5 per ENV var FLOSS_FUNDING_FIXTURE_GROUP_1..10
# - For gems 51..60: shared namespace BenchGemShared and a single ENV var FLOSS_FUNDING_FIXTURE_FINAL_10
if current_num <= 50
  mod_name = "BenchGem%02d" % current_num
  group = ((current_num - 1) / 5) + 1
  env_name = "FLOSS_FUNDING_FIXTURE_GROUP_#{group}"
else
  mod_name = "BenchGemShared"
  env_name = "FLOSS_FUNDING_FIXTURE_FINAL_10"
end

# Define module and Core submodule
unless Object.const_defined?(mod_name)
  Object.const_set(mod_name, Module.new)
end
mod = Object.const_get(mod_name)
mod.const_set(:Core, Module.new) unless mod.const_defined?(:Core)

# Conditionally include Poke based on env_name
if ENV.fetch(env_name, "0") != "0"
  require "floss_funding"
  mod::Core.send(:include, FlossFunding::Poke.new(__FILE__, mod_name))
end
      RUBY
    end
  end
end
