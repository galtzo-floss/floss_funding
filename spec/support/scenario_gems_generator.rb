# frozen_string_literal: true

# Generator for scenario-based fixture gems used in specs.
# These gems are created under spec/fixtures/scenario_gems and are intended
# to be persistent across runs (i.e., not re-generated each spec run).
# If you need to (re)generate them locally, you can require this file and call:
#   FlossFunding::ScenarioGemsGenerator.generate_all
# This uses GemMine under the hood to scaffold the gems.

require "gem_mine"

module FlossFunding
  module ScenarioGemsGenerator
    module_function

    ROOT = File.expand_path("../fixtures/scenario_gems", __dir__)

    def generate_all
      FileUtils.mkdir_p(ROOT)
      gen_gem_with_poked_vendored_gem
      gen_poked_gem_with_poked_vendored_gem
      gen_poked_gem_with_exe
      gen_poked_gem_with_poked_exe
      gen_poked_gem_with_dummy_spec_app
    end

    # Helper to create a gem-like folder with deterministic directory name equal to `name`
    # Accepts options similar to GemMine.factory but only uses a subset:
    # - :file_contents => { relative_path => content_string }
    # - :yaml_templates => { relative_path => content_string }
    # - :gemspec_extras (ignored; kept for API compatibility)
    # - :dependencies (ignored)
    def run_factory_with_dir_name(name, options = {})
      gem_dir = File.join(ROOT, name)
      FileUtils.rm_rf(gem_dir)
      FileUtils.mkdir_p(gem_dir)

      # Write YAML templates first
      (options[:yaml_templates] || {}).each do |rel, content|
        path = File.join(gem_dir, rel.to_s)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, content.to_s)
      end

      # Write files
      (options[:file_contents] || {}).each do |rel, content|
        path = File.join(gem_dir, rel.to_s)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, content.to_s)
      end

      # Return metadata similar to GemMine
      {:dir => gem_dir}
    end

    def floss_dep
      {:name => "floss_funding", :path => "../../../.."}
    end

    def yaml_for(lib)
      <<-YML
        library_name: #{lib}
        funding_uri: https://example.com/#{lib}
      YML
    end

    # 1. gem_with_poked_vendored_gem: Only vendored gem invokes Poke.new.
    def gen_gem_with_poked_vendored_gem
      name = "gem_with_poked_vendored_gem"
      mod = GemMine::Helpers.camelize(name)
      vend_name = "vendored_gem"
      vend_mod = GemMine::Helpers.camelize(vend_name)

      run_factory_with_dir_name(
        name,
        :gemspec_extras => {:files_glob => "{lib,bin,vendor}/**/*"},
        :yaml_templates => {".floss_funding.yml" => ""}, # main gem has no Poke, config optional
        :file_contents => {
          File.join("lib", "#{name}.rb") => <<-RUBY,
            # frozen_string_literal: true
            module #{mod}
              # Require the vendored gem
              require_relative "../vendor/#{vend_name}/lib/#{vend_name}"
            end
          RUBY
          File.join("vendor", vend_name, ".floss_funding.yml") => yaml_for(vend_name),
          File.join("vendor", vend_name, "lib", "#{vend_name}.rb") => <<-RUBY,
            # frozen_string_literal: true
            module #{vend_mod}
              module Core; end
            end
            require "floss_funding"
            #{vend_mod}::Core.send(:include, FlossFunding::Poke.new(__FILE__, namespace: #{vend_mod.inspect}))
          RUBY
        },
      )
    end

    # 2. poked_gem_with_poked_vendored_gem: Both gems invoke Poke.new.
    def gen_poked_gem_with_poked_vendored_gem
      name = "poked_gem_with_poked_vendored_gem"
      mod = GemMine::Helpers.camelize(name)
      vend_name = "vendored_gem"
      vend_mod = GemMine::Helpers.camelize(vend_name)

      run_factory_with_dir_name(
        name,
        :gemspec_extras => {:files_glob => "{lib,bin,vendor}/**/*"},
        :yaml_templates => {".floss_funding.yml" => yaml_for(name)},
        :file_contents => {
          File.join("lib", "#{name}.rb") => <<-RUBY,
            # frozen_string_literal: true
            module #{mod}
              module Core; end
            end
            require "floss_funding"
            #{mod}::Core.send(:include, FlossFunding::Poke.new(__FILE__, namespace: #{mod.inspect}))
            # Require the vendored gem
            require_relative "../vendor/#{vend_name}/lib/#{vend_name}"
          RUBY
          File.join("vendor", vend_name, ".floss_funding.yml") => yaml_for(vend_name),
          File.join("vendor", vend_name, "lib", "#{vend_name}.rb") => <<-RUBY,
            # frozen_string_literal: true
            module #{vend_mod}
              module Core; end
            end
            require "floss_funding"
            #{vend_mod}::Core.send(:include, FlossFunding::Poke.new(__FILE__, namespace: #{vend_mod.inspect}))
          RUBY
        },
      )
    end

    # 3. poked_gem_with_exe: exe loads lib; lib invokes Poke.new.
    def gen_poked_gem_with_exe
      name = "poked_gem_with_exe"
      mod = GemMine::Helpers.camelize(name)

      run_factory_with_dir_name(
        name,
        :gemspec_extras => {:files_glob => "{lib,bin}/**/*"},
        :yaml_templates => {".floss_funding.yml" => yaml_for(name)},
        :file_contents => {
          File.join("lib", "#{name}.rb") => <<-RUBY,
            # frozen_string_literal: true
            module #{mod}
              module Core; end
            end
            require "floss_funding"
            #{mod}::Core.send(:include, FlossFunding::Poke.new(__FILE__, namespace: #{mod.inspect}))
          RUBY
          File.join("bin", name) => <<-RUBY,
            #!/usr/bin/env ruby
            # frozen_string_literal: true
            $LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
            require "poked_gem_with_exe"
            puts "ok"
          RUBY
        },
      )
    end

    # 4. poked_gem_with_poked_exe: exe loads lib and also invokes Poke.new.
    def gen_poked_gem_with_poked_exe
      name = "poked_gem_with_poked_exe"
      mod = GemMine::Helpers.camelize(name)

      run_factory_with_dir_name(
        name,
        :gemspec_extras => {:files_glob => "{lib,bin}/**/*"},
        :yaml_templates => {".floss_funding.yml" => yaml_for(name)},
        :file_contents => {
          File.join("lib", "#{name}.rb") => <<-RUBY,
            # frozen_string_literal: true
            module #{mod}
              module Core; end
            end
            require "floss_funding"
            #{mod}::Core.send(:include, FlossFunding::Poke.new(__FILE__, namespace: #{mod.inspect}))
          RUBY
          File.join("bin", name) => <<-RUBY,
            #!/usr/bin/env ruby
            # frozen_string_literal: true
            $LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
            require "poked_gem_with_poked_exe"
            module PokedGemWithPokedExeExecutable; end
            require "floss_funding"
            PokedGemWithPokedExeExecutable.extend(Module.new)
            PokedGemWithPokedExeExecutable.send(:include, FlossFunding::Poke.new(nil, wedge: true))
            puts "ok"
          RUBY
        },
      )
    end

    # 5. poked_gem_with_dummy_spec_app: gem with spec/dummy that loads it
    def gen_poked_gem_with_dummy_spec_app
      name = "poked_gem_with_dummy_spec_app"
      mod = GemMine::Helpers.camelize(name)

      run_factory_with_dir_name(
        name,
        :gemspec_extras => {:files_glob => "{lib,spec}/**/*"},
        :yaml_templates => {".floss_funding.yml" => yaml_for(name)},
        :file_contents => {
          File.join("lib", "#{name}.rb") => <<-RUBY,
            # frozen_string_literal: true
            module #{mod}
              module Core; end
            end
            require "floss_funding"
            #{mod}::Core.send(:include, FlossFunding::Poke.new(__FILE__, namespace: #{mod.inspect}))
          RUBY
          File.join("spec", "dummy", "app.rb") => <<-RUBY,
            # frozen_string_literal: true
            $LOAD_PATH.unshift(File.expand_path("../../lib", __dir__))
            require #{name.inspect}
            puts "dummy-ok"
          RUBY
        },
      )
    end
  end
end
