# frozen_string_literal: true

module GemMine
  module Helpers
    SPLIT_UNDERSCORE_OR_SPACE = /[_\s]+/.freeze
    UPPERCASE_GROUPS = /([A-Z]+)([A-Z][a-z])/.freeze
    LOWER_UPPER_GROUPS = /([a-z\d])([A-Z])/.freeze

    module_function

    # Returns Ruby code string that, when evaluated inside a gem's lib file,
    # will require floss_funding and include the Poke module into the given
    # namespace's Core submodule. The ns argument should be a constant path
    # string, e.g. "BenchGem01" or "MyNS::BenchGem01".
    def poke_include(ns)
      <<~RUBY
        require "floss_funding"
        #{ns}::Core.send(:include, FlossFunding::Poke.new(__FILE__, namespace: #{ns.inspect}))
      RUBY
    end

    # Returns a Ruby expression string that checks if the given env var is enabled.
    # Example usage inside ERB: <%= helpers.env_enabled?(env_group_var) %>
    def env_enabled?(var_name)
      %(ENV.fetch(#{var_name.inspect}, "0") != "0")
    end

    # Simple camelize for typical library_name strings like "bench_gem_01" -> "BenchGem01"
    def camelize(str)
      str.to_s.split(SPLIT_UNDERSCORE_OR_SPACE).map { |s| s[0] ? s[0].upcase + s[1..-1].to_s : s }.join
    end

    # Simple underscore for ModuleName -> module_name
    def underscore(str)
      s = str.to_s.gsub("::", "/")
      s = s.gsub(UPPERCASE_GROUPS, '\\1_\\2')
      s = s.gsub(LOWER_UPPER_GROUPS, '\\1_\\2')
      s.tr("-", "_").downcase
    end
  end
end
