# frozen_string_literal: true

# Non-gem Bundler project fixture (has Gemfile, no gemspec)
# Namespace: NgBundler5
# Inclusion controlled by ENV["NG_BUNDLER_5_ENABLE"].

mod_name = "NgBundler5"
core_name = :Core

unless Object.const_defined?(mod_name)
  Object.const_set(mod_name, Module.new)
end
mod = Object.const_get(mod_name)
mod.const_set(core_name, Module.new) unless mod.const_defined?(core_name)

if ENV.fetch("NG_BUNDLER_5_ENABLE", "0") != "0"
  require "floss_funding"
  mod::Core.send(:include, FlossFunding::Poke.new(__FILE__, :namespace => mod_name))
end
