# frozen_string_literal: true

# std libs
require "openssl"

# this gem
require "floss_funding"

module FlossFunding
  # This module loads inside an anonymous module on Ruby 3.1+.
  # This is why FlossFunding herein uses top-level namespace as `::FlossFunding`.
  module Check
    def self.included(base, now = Time.now)
      base.extend(ClassMethods)
      ClassMethods.now_time = now
    end

    def self.extended(base, now = Time.now)
      base.extend(ClassMethods)
      ClassMethods.now_time = now
    end

    module ClassMethods
      class << self
        attr_accessor :now_time
      end

      def floss_funding_decrypt(license_key, namespace)
        return false if license_key.empty?

        cipher = OpenSSL::Cipher.new("aes-256-cbc").decrypt
        cipher.key = Digest::MD5.hexdigest(namespace)
        s = [license_key].pack("H*")

        cipher.update(s) + cipher.final
      end

      def check_unpaid_silence(license_key, namespace)
        case license_key
        when ::FlossFunding::FREE_AS_IN_BEER, ::FlossFunding::BUSINESS_IS_NOT_GOOD_YET, "#{::FlossFunding::NOT_FINANCIALLY_SUPPORTING}-#{namespace}"
          # Configured as unpaid
          true
        else
          # Might be configured as paid
          false
        end
      end

      def base_words
        ::FlossFunding.base_words(num_valid_words_for_month)
      end

      def check_license(plain_text)
        binary_search_result = base_words.bsearch { |word| plain_text == word }
        !!binary_search_result
      end

      def floss_funding_initiate_begging(license_key, namespace, env_var_name)
        if license_key.empty?
          # No license key provided
          ::FlossFunding.add_unlicensed(namespace)
          return start_begging(namespace, env_var_name)
        end

        # A silent short circuit for valid unpaid licenses
        if check_unpaid_silence(license_key, namespace)
          ::FlossFunding.add_licensed(namespace)
          return
        end

        valid_license_hex = license_key.match?(::FlossFunding::HEX_LICENSE_RULE)
        unless valid_license_hex
          # Invalid license format
          ::FlossFunding.add_unlicensed(namespace)
          return start_coughing(license_key, namespace, env_var_name)
        end

        # decrypt the license key for this namespace
        plain_text = floss_funding_decrypt(license_key, namespace)

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

      # Using the month gem to easily do month math
      def num_valid_words_for_month
        now_month - ::FlossFunding::START_MONTH
      end

      def now_month
        Month.new(ClassMethods.now_time.year, ClassMethods.now_time.month).to_i
      end

      def start_coughing(license_key, namespace, env_var_name)
        puts <<-COUGHING
==============================================================
COUGH, COUGH.
Ahem, it appears as though you might be using #{namespace} for free.
It looks like you tried to set a license key, but it was invalid.

  Current (Invalid) License Key: #{license_key}
  Namespace: #{namespace}
  ENV Variable: #{env_var_name}

Paid license keys are 64 characters long.
Unpaid license keys have varying lengths, depending on type and namespace.
Yours is #{license_key.length} characters long, and doesn't match any paid or unpaid keys.

Please unset the current ENV variable #{env_var_name}, since it is invalid.

Then find the correct one, or get a new one @ https://floss-funding.dev and set it.

#{footer}
        COUGHING
      end

      def start_begging(namespace, env_var_name)
        # Get configuration for this namespace
        config = ::FlossFunding.configuration(namespace) || {}

        # Use configuration values or defaults
        funding_url = config["floss_funding_url"] || "https://floss-funding.dev"
        suggested_amount = config["suggested_donation_amount"] || 5

        puts <<-BEGGING
==============================================================
Unremunerated use of #{namespace} detected!

FlossFunding (#{funding_url}) relies on empathy, respect, honor, and annoyance of the most extreme mildness.

👉️ No network calls. 👉️ No tracking. 👉️ No oversight. 👉️ Minimal crypto hashing.

Options:
  1. 🌐  Donate or sponsor @ #{funding_url}
     and affirm, on your honor, your donor or sponsor status.
     a. Receive ethically-sourced, buy-once, license key for #{namespace}.
     b. Suggested donation amount: $#{suggested_amount}

  2. 🪄  If open source, or not-for-profit, continue to use #{namespace} for free, with license key: "#{::FlossFunding::FREE_AS_IN_BEER}".

  3. 🏦  If commercial, continue to use #{namespace} for free, & feel a bit naughty, with license key: "#{::FlossFunding::BUSINESS_IS_NOT_GOOD_YET}".

  4. ✖️  Disable license checks for #{namespace} with license key: "#{::FlossFunding::NOT_FINANCIALLY_SUPPORTING}-#{namespace}".

Then in Ruby (before the gem, referenced by "#{namespace}", loads) do:

  ENV["#{env_var_name}"] = "<your key from one of the options above>"

Or in shell / dotenv / direnv:

  export #{env_var_name}="<your key from one of the options above>"

#{footer}
        BEGGING
      end

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
