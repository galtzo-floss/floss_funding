# frozen_string_literal: true

require "erb"
require "fileutils"

module GemMine
  # Internal engine for GemMine.factory
  class Generator
    DEFAULTS = {
      :count => 100,
      :root_dir => File.expand_path("../../spec/fixtures/gem_mine", __dir__),
      :gem_name_prefix => "bench_gem_",
      :start_index => 1,
      :group_size => 10,
      :groups_env_prefix => "GEM_MINE_GROUP_",
      :namespace_proc => nil,
      :include_floss_funding => false,
      :dependencies => [],
      :authors => [],
      :version_strategy => proc { |ctx| "0.0.#{ctx[:index]}" },
      :gemspec_extras => {},
      :yaml_templates => {},
      :file_contents => nil, # if nil, a minimal default lib file is generated via ERB
      :overwrite => true,
      :cleanup => false,
      :seed => nil,
      :after_generate => nil,
      :progress_bar => nil,
    }.freeze

    def initialize(options = {})
      @options = DEFAULTS.merge(options || {})
    end

    def run
      validate!
      srand(@options[:seed]) if @options[:seed]

      root_dir = File.expand_path(@options[:root_dir])
      FileUtils.rm_rf(root_dir) if @options[:cleanup]
      FileUtils.mkdir_p(root_dir)

      gems_meta = []

      count = @options[:count].to_i
      start_index = @options[:start_index].to_i
      group_size = @options[:group_size].to_i

      # Optional progress bar
      progress_bar_options = @options[:progress_bar]
      bar = nil
      if progress_bar_options
        begin
          require "ruby-progressbar"
          opts = progress_bar_options.dup
          opts[:total] ||= count
          bar = ProgressBar.create(opts)
        rescue LoadError
          bar = nil
        end
      end

      count.times do |offset|
        index = start_index + offset
        ordinal = offset
        group_index = (ordinal / group_size)

        gem_name = format_name(@options[:gem_name_prefix], index, count)
        module_name = Helpers.camelize(gem_name)
        gem_dir = File.join(root_dir, gem_name)
        lib_dir = File.join(gem_dir, "lib")
        FileUtils.mkdir_p(lib_dir)

        env_group_var = "#{@options[:groups_env_prefix]}#{group_index}"

        # Build per-gem context used by ERB templates and value callables
        ctx = build_context(
          :index => index,
          :ordinal => ordinal,
          :count => count,
          :group_size => group_size,
          :group_index => group_index,
          :groups_env_prefix => @options[:groups_env_prefix],
          :env_group_var => env_group_var,
          :root_dir => root_dir,
          :gem_dir => gem_dir,
          :lib_dir => lib_dir,
          :gem_name => gem_name,
          :module_name => module_name,
          :include_floss_funding => !!@options[:include_floss_funding]
        )

        ctx[:namespace] = call_opt(@options[:namespace_proc], ctx)
        ctx[:dependencies] = normalize_dependencies(call_opt(@options[:dependencies], ctx))

        # Write Gemfile and gemspec
        gemfile_path = File.join(gem_dir, "Gemfile")
        gemspec_path = File.join(gem_dir, "#{gem_name}.gemspec")

        write_gemfile(gemfile_path, ctx[:dependencies], @options[:overwrite])

        authors = call_opt(@options[:authors], ctx) || []
        version = call_opt(@options[:version_strategy], ctx)
        extras = symbolize_keys(call_opt(@options[:gemspec_extras], ctx) || {})
        write_gemspec(gemspec_path, gem_name, version, authors, extras, ctx, @options[:overwrite])

        # YAML templates
        yaml_templates = call_opt(@options[:yaml_templates], ctx) || {}
        write_yaml_templates(gem_dir, yaml_templates, ctx, @options[:overwrite])

        # Files (lib and others)
        files_templates = call_opt(@options[:file_contents], ctx)
        if files_templates.nil? || files_templates.empty?
          # Provide default minimal lib file rendered via ERB
          files_templates = {
            File.join("lib", "#{gem_name}.rb") => default_lib_template,
          }
        end
        write_file_templates(gem_dir, files_templates, ctx, @options[:overwrite])

        per_gem = {
          :index => index,
          :gem_name => gem_name,
          :module_name => module_name,
          :namespace => ctx[:namespace],
          :group_index => group_index,
          :env_group_var => env_group_var,
          :dir => gem_dir,
          :lib_dir => lib_dir,
          :gemspec_path => gemspec_path,
          :gemfile_path => gemfile_path,
        }

        gems_meta << per_gem

        if @options[:after_generate].respond_to?(:call)
          @options[:after_generate].call(:result => nil, :gem => per_gem)
        end

        bar&.increment
      end

      bar&.finish if bar && bar.respond_to?(:finish)

      {
        :root_dir => root_dir,
        :groups => { :env_prefix => @options[:groups_env_prefix], :group_size => group_size },
        :gems => gems_meta,
      }
    end

    private

    def validate!
      raise ArgumentError, "count must be positive" unless @options[:count].to_i > 0
      raise ArgumentError, "group_size must be positive" unless @options[:group_size].to_i > 0
      true
    end

    def build_context(base)
      base[:helpers] = Helpers
      base
    end

    def call_opt(opt, ctx)
      return opt.call(ctx) if opt.respond_to?(:call)
      opt
    end

    def format_name(prefix, index, count)
      width = [count.to_s.size, 2].max
      num = format("%0#{width}d", index)
      "#{prefix}#{num}"
    end

    def default_lib_template
      <<~'RUBY'
        # frozen_string_literal: true

        module <%= module_name %>
          module Core; end
        end

        if ENV.fetch("<%= env_group_var %>", "0") != "0" && <%= include_floss_funding.inspect %>
          <%= helpers.poke_include(namespace || module_name) %>
        end
      RUBY
    end

    def write_gemfile(path, deps, overwrite)
      return if File.exist?(path) && !overwrite

      lines = []
      lines << "# frozen_string_literal: true"
      lines << "source \"https://rubygems.org\""
      lines << ""

      deps.each do |d|
        gem_line = build_gem_line(d)
        lines << gem_line if gem_line
      end

      lines << ""
      lines << "gemspec"

      File.write(path, lines.join("\n") + "\n")
    end

    def build_gem_line(dep)
      name = dep[:name] || dep["name"]
      return nil unless name

      parts = ["gem \"#{name}\""]

      versions = dep[:version] || dep["version"]
      if versions
        versions = Array(versions)
        parts.concat(versions.map { |v| v.inspect }) unless dep[:git] || dep[:path]
      end

      if dep[:path]
        parts << ":path => #{dep[:path].inspect}"
      elsif dep[:git]
        parts << ":git => #{dep[:git].inspect}"
        parts << ":branch => #{dep[:branch].inspect}" if dep[:branch]
        parts << ":ref => #{dep[:ref].inspect}" if dep[:ref]
        parts << ":tag => #{dep[:tag].inspect}" if dep[:tag]
      end

      parts << ":require => #{dep[:require].inspect}" if dep.key?(:require)

      "#{parts.join(", ")}"
    end

    def write_gemspec(path, gem_name, version, authors, extras, ctx, overwrite)
      return if File.exist?(path) && !overwrite

      files_glob = extras[:files_glob] || "lib/**/*.rb"
      require_paths = extras[:require_paths] || ["lib"]

      body = []
      body << "# frozen_string_literal: true"
      body << "Gem::Specification.new do |s|"
      if extras[:name_literal]
        body << "  s.name        = #{extras[:name_literal]}"
      else
        body << "  s.name        = #{gem_name.inspect}"
      end
      body << "  s.version     = #{version.inspect}"
      summary = extras[:summary] || "Generated gem #{gem_name}"
      body << "  s.summary     = #{summary.inspect}"
      body << "  s.description = #{extras[:description].inspect}" if extras.key?(:description)
      body << "  s.authors     = #{Array(authors).inspect}"
      body << "  s.files       = Dir[#{files_glob.inspect}]"
      body << "  s.require_paths = #{Array(require_paths).inspect}"
      if (licenses = extras[:licenses])
        body << "  s.licenses = #{Array(licenses).inspect}"
      end
      if (metadata = extras[:metadata])
        body << "  s.metadata = #{symbolize_keys(metadata).inspect}"
      end

      # add runtime dependencies to gemspec (names only or with version)
      ctx[:dependencies].each do |dep|
        name = dep[:name] || dep["name"]
        next unless name
        version = dep[:version] || dep["version"]
        if version
          Array(version).each do |v|
            body << "  s.add_dependency #{name.inspect}, #{v.inspect}"
          end
        else
          body << "  s.add_dependency #{name.inspect}"
        end
      end

      body << "end"

      File.write(path, body.join("\n") + "\n")
    end

    def write_yaml_templates(gem_dir, templates, ctx, overwrite)
      templates.each do |key, tmpl|
        rel, ext = yaml_key_to_filename_and_ext(key)
        target = File.join(gem_dir, "#{rel}.#{ext}")
        next if File.exist?(target) && !overwrite
        rendered = render_erb(tmpl.to_s, ctx)
        FileUtils.mkdir_p(File.dirname(target))
        File.write(target, rendered)
      end
    end

    def yaml_key_to_filename_and_ext(key)
      str = key.to_s
      if (m = /(.*)_ya?ml\z/.match(str))
        [m[1], (str.end_with?("yaml") ? "yaml" : "yml")]
      elsif str.end_with?(".yml")
        [str.sub(/\.yml\z/, ""), "yml"]
      elsif str.end_with?(".yaml")
        [str.sub(/\.yaml\z/, ""), "yaml"]
      else
        # default to .yml
        [str, "yml"]
      end
    end

    def write_file_templates(gem_dir, templates, ctx, overwrite)
      templates.each do |rel_path, tmpl|
        target = File.join(gem_dir, rel_path.to_s)
        next if File.exist?(target) && !overwrite
        rendered = render_erb(tmpl.to_s, ctx)
        FileUtils.mkdir_p(File.dirname(target))
        File.write(target, rendered)
      end
    end

    def render_erb(template, ctx_hash)
      context = build_erb_context(ctx_hash)
      ERB.new(template, trim_mode: "-").result(context.__binding__)
    end

    def build_erb_context(ctx_hash)
      CtxObj.new(ctx_hash)
    end

    class CtxObj
      def initialize(hash)
        @__hash__ = hash
        hash.each do |k, v|
          define_singleton_method(k) { v }
        end
      end

      def __binding__
        binding
      end
    end

    def normalize_dependencies(deps)
      deps = [] if deps.nil?
      deps = [deps] unless deps.is_a?(Array)
      deps.map { |d| symbolize_keys(d || {}) }
    end

    def symbolize_keys(obj)
      case obj
      when Hash
        obj.each_with_object({}) { |(k, v), h| h[(k.is_a?(String) ? k.to_sym : k)] = symbolize_keys(v) }
      when Array
        obj.map { |v| symbolize_keys(v) }
      else
        obj
      end
    end
  end
end
