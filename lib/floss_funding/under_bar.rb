module FlossFunding
  # This module helps to upcase and underscore class names / namespaces.
  # It was stolen from the shields-badge gem, because I did good work there, and then modified.
  # See: https://github.com/galtzo-floss/shields-badge/blob/main/lib/shields/badge.rb
  # It provides protection against malicious class names.
  module UnderBar
    DEFAULT_PREFIX = "FLOSS_FUNDING_"
    SAFE_TO_UNDERSCORE = /\A[\p{UPPERCASE-LETTER}\p{LOWERCASE-LETTER}\p{DECIMAL-NUMBER}]{1,256}\Z/
    SUBBER_UNDER = /(\p{UPPERCASE-LETTER})/
    INITIAL_UNDERSCORE = /^_/

    class << self
      def env_variable_name(opts = {})
        namespace = opts[:namespace]
        prefix = opts[:prefix] || DEFAULT_PREFIX
        raise FlossFunding::Error, "namespace must be a String, but is #{namespace.class}" unless namespace.is_a?(String)

        name_parts = namespace.split("::")
        env_name = name_parts.map { |np| to_under_bar(np) }.join("_")
        "#{prefix}#{env_name}".upcase
      end

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
