# frozen_string_literal: true

# std libs
require "openssl"

module FlossFunding
  # This module loads inside an anonymous module on Ruby 3.1+.
  # This is why FlossFunding herein uses top-level namespace as `::FlossFunding`.
  module Check
    # When this module is included, extend the target with class-level helpers
    # and set the deterministic time source (used in specs via Timecop).
    #
    # @param base [Module] the including module
    # @param now [Time] the current time (defaults to Time.now)
    # @return [void]
    def self.included(base, now = Time.now)
      base.extend(ClassMethods)
      # Set global time source on FlossFunding
      ::FlossFunding.now_time = now
      ClassMethods.now_time = now
    end

    # When this module is extended, also extend with class-level helpers and
    # set the deterministic time source.
    #
    # @param base [Module] the extending module
    # @param now [Time] the current time (defaults to Time.now)
    # @return [void]
    def self.extended(base, now = Time.now)
      base.extend(ClassMethods)
      ::FlossFunding.now_time = now
      ClassMethods.now_time = now
    end

    # Class-level API used by FlossFunding::Poke to perform activation checks
    # and generate user-facing messages. Methods here are intended for inclusion
    # into client libraries when they `extend FlossFunding::Check`.
    module ClassMethods
      class << self
        # Time source used for month arithmetic and testing.
        # @return [Time]
        attr_accessor :now_time
      end

      # Returns the list of valid plain text base words for the current month window.
      #
      # @return [Array<String>]
      def base_words
        ::FlossFunding.base_words(num_valid_words_for_month)
      end

      # Checks whether the given plaintext matches a valid plaintext base word.
      #
      # @param plain_text [String]
      # @return [Boolean]
      def check_activation(plain_text)
        words = base_words
        # Use fast binary search when available (Ruby >= 2.0), else fall back to include?
        # We can't run CI on Ruby < 2.3 so the alternate branch is not going to have test coverage.
        # :nocov:
        if words.respond_to?(:bsearch)
          !!words.bsearch { |word| plain_text == word }
        else
          words.include?(plain_text)
        end
        # :nocov:
      end

      # Entry point for activation key evaluation and output behavior.
      # Now accepts a precomputed ActivationEvent and emits messages/registrations based on its state.
      #
      # @param event [FlossFunding::ActivationEvent]
      # @return [void]
      def floss_funding_initiate_begging(event)
        library = event.library
        namespace = library.namespace
        env_var_name = ::FlossFunding::UnderBar.env_variable_name(namespace)
        gem_name = library.gem_name
        activation_key = event.activation_key

        case event.state
        when ::FlossFunding::STATES[:activated]
          # Already recorded as activated via ActivationEvent; no output necessary.
          nil
        when ::FlossFunding::STATES[:invalid]
          # Invalid key format: emit diagnostic output.
          start_coughing(activation_key, namespace, env_var_name)
        else # unactivated
          # Missing/invalid activation after decryption: emit friendly reminder.
          start_begging(namespace, env_var_name, gem_name)
        end
      end

      private

      # Using the month gem to easily do month math.
      #
      # @return [Integer] number of valid words based on the month offset
      def num_valid_words_for_month
        ::FlossFunding.num_valid_words_for_month
      end

      # Returns the Month integer for the configured time source.
      #
      # @return [Integer]
      def now_month
        ::FlossFunding.now_month
      end

      # Emits a diagnostic message for invalid activation key format.
      #
      # @param activation_key [String]
      # @param namespace [String]
      # @param env_var_name [String]
      # @return [void]
      def start_coughing(activation_key, namespace, env_var_name)
        ::FlossFunding.start_coughing(activation_key, namespace, env_var_name)
      end

      # Emits the standard friendly funding message for unactivated usage.
      #
      # @param namespace [String]
      # @param env_var_name [String]
      # @return [void]
      def start_begging(namespace, env_var_name, gem_name)
        ::FlossFunding.start_begging(namespace, env_var_name, gem_name)
      end
    end
  end
end
