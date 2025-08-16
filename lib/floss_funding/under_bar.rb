module FlossFunding
  # Utilities to convert Ruby namespaces to safe, uppercased, underscore forms
  # for environment variable names. Protects against malicious or invalid class
  # names via conservative character rules.
  #
  # See also: https://github.com/galtzo-floss/shields-badge/blob/main/lib/shields/badge.rb
  module UnderBar
    # Allowed characters for a single namespace segment. Max length 256 to avoid abuse.
    # @return [Regexp]
    SAFE_TO_UNDERSCORE = /\A[\p{UPPERCASE-LETTER}\p{LOWERCASE-LETTER}\p{DECIMAL-NUMBER}]{1,256}\Z/

    # Pattern to insert underscores before capital letters.
    # @return [Regexp]
    SUBBER_UNDER = /(\p{UPPERCASE-LETTER})/

    # Pattern for a leading underscore to be removed after transformation.
    # @return [Regexp]
    INITIAL_UNDERSCORE = /^_/

    class << self
      # Internal memoization cache for env var names
      def _cache
        @cache ||= {}
      end

      def reset_cache!
        @cache = {}
      end

      # Builds an uppercased ENV variable name from a Ruby namespace.
      #
      # @param namespace [FlossFunding::Namespace, String] the Ruby namespace (e.g., "My::Lib")
      # @return [String] the resulting ENV variable name
      # @raise [FlossFunding::Error] when :namespace is not a String or contains invalid characters
      def env_variable_name(namespace)
        return namespace.env_var_name if namespace.respond_to?(:env_var_name)

        raise FlossFunding::Error, "namespace must be a String, but is #{namespace.class}" unless namespace.is_a?(String)

        cached = _cache[namespace]
        return cached if cached

        name_parts = namespace.split("::")
        env_name = name_parts.map { |np| to_under_bar(np) }.join("__")
        result = "#{::FlossFunding::Constants::DEFAULT_PREFIX}#{env_name}".upcase
        _cache[namespace] = result.freeze
      end

      # Converts a single namespace segment to an underscored, uppercased string.
      #
      # @param string [String] the namespace segment to convert
      # @return [String] an uppercased, underscore-separated representation
      # @raise [FlossFunding::Error] when the string contains invalid characters or is too long
      def to_under_bar(string)
        safe = string[SAFE_TO_UNDERSCORE]
        raise FlossFunding::Error, "Invalid! Each part of klass name must match #{SAFE_TO_UNDERSCORE}: #{safe} (#{safe.class}) != #{string[0..255]} (#{string.class})" unless safe == string.to_s

        underscored = safe.gsub(SUBBER_UNDER) { "_#{$1}" }
        shifted_leading_underscore = underscored.sub(INITIAL_UNDERSCORE, "")
        shifted_leading_underscore.upcase
      end
    end
  end
end
