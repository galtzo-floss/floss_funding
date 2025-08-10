# frozen_string_literal: true

# std libs
require "openssl"

# this gem
require "floss_funding"

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
      ClassMethods.now_time = now
    end

    module ClassMethods
      class << self
        # Time source used for month arithmetic and testing.
        # @return [Time]
        attr_accessor :now_time
      end

      # Decrypts a hex-encoded activation key using a namespace-derived key.
      #
      # @param activation_key [String] 64-character hex string for paid activation
      # @param namespace [String] the namespace used to derive the cipher key
      # @return [String, false] plaintext license word on success; false if empty
      def floss_funding_decrypt(activation_key, namespace)
        return false if activation_key.empty?

        cipher = OpenSSL::Cipher.new("aes-256-cbc").decrypt
        cipher.key = Digest::MD5.hexdigest(namespace)
        s = [activation_key].pack("H*")

        cipher.update(s) + cipher.final
      end

      # Returns true if activation_key indicates an unpaid or opted-out license that
      # should not emit any console output (silent success).
      #
      # @param activation_key [String]
      # @param namespace [String]
      # @return [Boolean]
      def check_unpaid_silence(activation_key, namespace)
        case activation_key
        when ::FlossFunding::FREE_AS_IN_BEER, ::FlossFunding::BUSINESS_IS_NOT_GOOD_YET, "#{::FlossFunding::NOT_FINANCIALLY_SUPPORTING}-#{namespace}"
          # Configured as unpaid
          true
        else
          # Might be configured as paid
          false
        end
      end

      # Returns the list of valid license words for the current month window.
      #
      # @return [Array<String>]
      def base_words
        ::FlossFunding.base_words(num_valid_words_for_month)
      end

      # Checks whether the given plaintext matches a valid license word.
      #
      # @param plain_text [String]
      # @return [Boolean]
      def check_license(plain_text)
        binary_search_result = base_words.bsearch { |word| plain_text == word }
        !!binary_search_result
      end

      # Entry point for license evaluation and output behavior.
      #
      # @param activation_key [String] value from ENV
      # @param namespace [String] namespace this license governs
      # @param env_var_name [String] the ENV variable name checked
      # @return [void]
      def floss_funding_initiate_begging(activation_key, namespace, env_var_name)
        if activation_key.empty?
          # No activation key provided
          ::FlossFunding.add_unlicensed(namespace)
          return start_begging(namespace, env_var_name)
        end

        # A silent short circuit for valid unpaid licenses
        if check_unpaid_silence(activation_key, namespace)
          ::FlossFunding.add_licensed(namespace)
          return
        end

        valid_license_hex = activation_key.match?(::FlossFunding::HEX_LICENSE_RULE)
        unless valid_license_hex
          # Invalid license format
          ::FlossFunding.add_unlicensed(namespace)
          return start_coughing(activation_key, namespace, env_var_name)
        end

        # decrypt the activation key for this namespace
        plain_text = floss_funding_decrypt(activation_key, namespace)

        # A silent short circuit for valid paid licenses
        if check_license(plain_text)
          ::FlossFunding.add_licensed(namespace)
          return
        end

        # No valid license found
        ::FlossFunding.add_unlicensed(namespace)
        start_begging(namespace, env_var_name)
      end

      private

      # Using the month gem to easily do month math.
      #
      # @return [Integer] number of valid words based on the month offset
      def num_valid_words_for_month
        now_month - ::FlossFunding::START_MONTH
      end

      # Returns the Month integer for the configured time source.
      #
      # @return [Integer]
      def now_month
        Month.new(ClassMethods.now_time.year, ClassMethods.now_time.month).to_i
      end

      # Emits a diagnostic message for invalid activation key format.
      #
      # @param activation_key [String]
      # @param namespace [String]
      # @param env_var_name [String]
      # @return [void]
      def start_coughing(activation_key, namespace, env_var_name)
        puts <<-COUGHING
==============================================================
COUGH, COUGH.
Ahem, it appears as though you might be using #{namespace} for free.
It looks like you tried to set an activation key, but it was invalid.

  Current (Invalid) Activation Key: #{activation_key}
  Namespace: #{namespace}
  ENV Variable: #{env_var_name}

Paid activation keys are 8 bytes, 64 hex characters, long.
Unpaid activation keys have varying lengths, depending on type and namespace.
Yours is #{activation_key.length} characters long, and doesn't match any paid or unpaid keys.

Please unset the current ENV variable #{env_var_name}, since it is invalid.

Then find the correct one, or get a new one @ https://floss-funding.dev and set it.

#{footer}
        COUGHING
      end

      # Emits the standard friendly funding message for unlicensed usage.
      #
      # @param namespace [String]
      # @param env_var_name [String]
      # @return [void]
      def start_begging(namespace, env_var_name)
        # During load, only emit a single-line note and defer the large blurb to at_exit
        puts %(FlossFunding: Activation key missing for #{namespace}. Set ENV[#{env_var_name}] to activation key; details will be shown at exit.)
      end

      # Footer appended to console messages.
      #
      # @return [String] formatted footer block including gem version
      def footer
        <<-FOOTER
==============================================================
- Please buy FLOSS licenses to support open source developers.
FlossFunding v#{::FlossFunding::Version::VERSION} is made with ❤️ in 🇺🇸 & 🇮🇩 by Galtzo FLOSS.
        FOOTER
      end
    end
  end
end
