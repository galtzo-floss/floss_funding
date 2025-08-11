# frozen_string_literal: true

# Script-only non-gem fixture (no Gemfile, no gemspec, no YAML)
# Namespace: NgScriptOnly
# Inclusion controlled by ENV["NG_SCRIPT_ONLY_ENABLE"].

mod_name = "NgScriptNoConfig"
core_name = :Core

unless Object.const_defined?(mod_name)
  Object.const_set(mod_name, Module.new)
end
mod = Object.const_get(mod_name)
mod.const_set(core_name, Module.new) unless mod.const_defined?(core_name)

if ENV.fetch("NG_SCRIPT_NO_CONFIG_ENABLE", "0") != "0"
  require "floss_funding"
  # Pass explicit namespace to Poke like other fixtures do
  mod::Core.send(:include, FlossFunding::Poke.new(__FILE__, :namespace => mod_name))
end
