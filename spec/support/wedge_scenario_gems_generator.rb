# frozen_string_literal: true

# Generator for wedge scenario fixture gems used in specs.
# These gems live under spec/fixtures/scenario_gems and should be re-creatable
# on demand so specs remain deterministic even if fixtures are cleaned.
# Usage:
#   FlossFunding::WedgeScenarioGemsGenerator.generate_all

require "fileutils"

module FlossFunding
  module WedgeScenarioGemsGenerator
    module_function

    ROOT = File.expand_path("../fixtures/scenario_gems", __dir__)

    def generate_all
      FileUtils.mkdir_p(ROOT)
      gen_gem1_with_vendored
      gen_gem2_exec_and_lib
      gen_gem3_exec_and_lib_both_poke
      gen_gem4_with_dummy
    end

    # Minimal deterministic writer (similar to ScenarioGemsGenerator#run_factory_with_dir_name)
    def write_dir(name, files = {}, yamls = {})
      gem_dir = File.join(ROOT, name)
      FileUtils.rm_rf(gem_dir)
      FileUtils.mkdir_p(gem_dir)

      yamls.each do |rel, content|
        path = File.join(gem_dir, rel.to_s)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, content.to_s)
      end

      files.each do |rel, content|
        path = File.join(gem_dir, rel.to_s)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, content.to_s)
      end

      {:dir => gem_dir}
    end

    def gen_gem1_with_vendored
      name = "gem1_with_vendored"
      files = {
        File.join("lib", "gem1_with_vendored.rb") => <<-RUBY,
          # frozen_string_literal: true

          # Main library module for gem1_with_vendored
          module Gem1WithVendored
            # In real usage this gem would "vendor" another gem inside its tree.
            # For fixture purposes, require the vendored lib.
            begin
              require "vendor_gem"
            rescue LoadError
              # Try relative require for test environments
              begin
                require_relative "../../vendor/vendored_lib/lib/vendor_gem"
              rescue LoadError
                # ignore if not present in load path yet
              end
            end

            # Optionally, this gem could also include FlossFunding directly, but Wedge will inject when run.
            # include FlossFunding::Poke.new(__FILE__)
          end
        RUBY
        File.join("vendor", "vendored_lib", "lib", "vendor_gem.rb") => <<-RUBY,
          # frozen_string_literal: true

          # Simulated vendored gem inside gem1_with_vendored
          module VendorGem
            # no direct Poke inclusion here; Wedge should be able to inject
          end
        RUBY
      }
      write_dir(name, files)
    end

    def gen_gem2_exec_and_lib
      name = "gem2_exec_and_lib"
      files = {
        File.join("lib", "gem2_exec_and_lib.rb") => <<-RUBY,
          # frozen_string_literal: true

          module Gem2ExecAndLib
            # Library body
          end
        RUBY
      }
      write_dir(name, files)
    end

    def gen_gem3_exec_and_lib_both_poke
      name = "gem3_exec_and_lib_both_poke"
      files = {
        File.join("lib", "gem3_exec_and_lib_both_poke.rb") => <<-RUBY,
          # frozen_string_literal: true

          module Gem3ExecAndLibBothPoke
            # Library body
          end
        RUBY
      }
      write_dir(name, files)
    end

    def gen_gem4_with_dummy
      name = "gem4_with_dummy"
      files = {
        File.join("lib", "gem4_with_dummy.rb") => <<-RUBY,
          # frozen_string_literal: true

          module Gem4WithDummy
          end
        RUBY
      }
      write_dir(name, files)
    end
  end
end
