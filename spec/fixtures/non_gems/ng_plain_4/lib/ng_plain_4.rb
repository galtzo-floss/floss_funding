# frozen_string_literal: true

# Non-Bundler non-gem project fixture (no Gemfile, no gemspec)
# Namespace: NgPlain4
# Inclusion controlled by ENV["NG_PLAIN_4_ENABLE"].

mod_name = "NgPlain4"
core_name = :Core

unless Object.const_defined?(mod_name)
  Object.const_set(mod_name, Module.new)
end
mod = Object.const_get(mod_name)
mod.const_set(core_name, Module.new) unless mod.const_defined?(core_name)

if ENV.fetch("NG_PLAIN_4_ENABLE", "0") != "0"
  require "floss_funding"
  mod::Core.send(:include, FlossFunding::Poke.new(__FILE__, mod_name))
end
