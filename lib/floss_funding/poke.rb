# frozen_string_literal: true

module FlossFunding
  # This module is the externally facing API for this gem.
  #
  # It supports two usage patterns:
  #
  # 1. Traditional namespace (uses the including module's name):
  #
  #     module MyGemLibrary
  #       include FlossFunding::Poke.new(__FILE__)
  #     end
  #
  # 2. Arbitrary custom namespace (can add version, or anything else):
  #
  #     module MyGemLibrary
  #       include FlossFunding::Poke.new(__FILE__, "Custom::Namespace::V4")
  #     end
  #
  module Poke
    # Use class << self for defining class methods
    class << self
      # Direct inclusion disallowed: including FlossFunding::Poke directly will raise.
      def included(base)
        raise ::FlossFunding::Error, "Do not include FlossFunding::Poke directly. Use include FlossFunding::Poke.new(__FILE__, optional_namespace, optional_env_prefix)."
      end

      # For custom (now standard) usage pattern: requires including file path
      # If env_prefix is nil, the default prefix will be used
      def new(including_path, namespace = nil, env_prefix = nil)
        Module.new do
          define_singleton_method(:included) do |base|
            FlossFunding::Poke.setup_begging(base, namespace, env_prefix, including_path)
          end
        end
      end

      # Common setup logic
      def setup_begging(base, custom_namespace, env_prefix, including_path)
        unless including_path.is_a?(String)
          raise ::FlossFunding::Error, "including_path must be a String file path (e.g., __FILE__), got #{including_path.class}"
        end
        checker =
          if RUBY_VERSION >= "3.1"
            # Load into an anonymous module to ensure no pollution from other gems loading the same module.
            Module.new.tap { |mod| Kernel.load("floss_funding/check.rb", mod) }::FlossFunding::Check
          else
            # For older Ruby versions, we need to use load instead of require to ensure fresh time
            Kernel.load("floss_funding/check.rb")
            ::FlossFunding::Check
          end

        # Extend the base with the checker module first
        base.extend(checker)

        # Three data points needed:
        # 1. namespace (derived from the base class name, if not given)
        # 2. ENV variable name (derived from namespace)
        # 3. license key (derived from ENV variable)
        namespace = (!custom_namespace || custom_namespace.empty?) ? base.name : custom_namespace
        env_var_name = ::FlossFunding::UnderBar.env_variable_name(
          {
            :prefix => env_prefix,
            :namespace => namespace,
          },
        )
        license_key = ENV.fetch(env_var_name, "")

        # Load configuration from .floss_funding.yml if it exists
        config = ::FlossFunding::Config.load_config(including_path)
        ::FlossFunding.set_configuration(namespace, config)

        # Now call the begging method after extending
        base.floss_funding_initiate_begging(license_key, namespace, env_var_name)
      end
    end
  end
end
