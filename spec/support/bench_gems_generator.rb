# frozen_string_literal: true

module FlossFunding
  module BenchGemsGenerator
    module_function

    # Compatibility wrapper to generate benchmark gems using GemMine
    # Default behavior: generate 100 gems under spec/fixtures/gem_mine
    # with bench_gem_XX naming and optional FlossFunding availability.
    def generate_all(count = 100, options = {})
      defaults = {
        :count => count,
        :root_dir => File.expand_path("../fixtures/gem_mine", __dir__),
        :library_name_prefix => "bench_gem_",
        :group_size => 10,
        :include_floss_funding => true,
        :dependencies => [{:name => "floss_funding", :path => "../../../.."}],
        :progress_bar => {:title => "GemMine", :format => "%t: |%B| %c/%C", :autofinish => true},
      }
      GemMine.factory(defaults.merge(options))
    end
  end
end
