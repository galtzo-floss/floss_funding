# frozen_string_literal: true
# :nocov:
require "uri"

module FlossFunding
  module Validators
    MAX_LEN = 512
    URL_KEYS = %w[
      funding_uri
      funding_subscription_uri
      funding_donation_uri
      homepage
    ].freeze

    module_function

    # Returns true if value is a String and longer than MAX_LEN
    def string_too_long?(value)
      value.is_a?(String) && value.length > MAX_LEN
    end

    # Minimal WHATWG-like validation suitable for our needs without extra deps.
    # - Accept only http/https
    # - Must have a host
    # - Full string length <= 512
    def valid_url?(value)
      return false unless value.is_a?(String)
      return false if value.length > MAX_LEN
      begin
        u = URI.parse(value)
        return false unless %w[http https].include?(u.scheme)
        return false if (u.host.nil? || u.host.empty?)
        true
      rescue URI::InvalidURIError, ArgumentError
        false
      end
    end

    # Deeply sanitize configuration Hash values.
    # - All strings longer than MAX_LEN are removed
    # - Keys that look like URLs (URL_KEYS or end with _uri/_url) must pass valid_url?
    # Returns [sanitized_hash, invalid_paths]
    # invalid_paths: array of strings like "authors[2]" or "funding_uri"
    def sanitize_config(data)
      invalids = []
      sanitized = deep_sanitize(data, [], invalids)
      [sanitized, invalids]
    end

    def deep_sanitize(obj, path, invalids)
      case obj
      when Hash
        out = {}
        obj.each do |k, v|
          key = k.to_s
          new_path = path + [key]
          if v.is_a?(String)
            if reject_string_for_key?(key, v)
              invalids << new_path.join(".")
              next
            end
            out[key] = [v]
          else
            val = deep_sanitize(v, new_path, invalids)
            out[key] = val unless val.nil? || (val.respond_to?(:empty?) && val.empty?)
          end
        end
        out
      when Array
        arr = []
        obj.each_with_index do |v, idx|
          new_path = path.dup
          # arrays are not included in attribute name for logging granularity add [idx]
          case v
          when String
            key = path.last
            if reject_string_for_key?(key, v)
              invalids << (path.empty? ? "[#{idx}]" : (path.join(".") + "[#{idx}]"))
              next
            end
            arr << v
          when Hash, Array
            val = deep_sanitize(v, new_path, invalids)
            arr << val unless val.nil? || (val.respond_to?(:empty?) && val.empty?)
          else
            arr << v
          end
        end
        arr
      when String
        if reject_string_for_key?(path.last, obj)
          invalids << path.join(".")
          nil
        else
          obj
        end
      else
        obj
      end
    end

    def reject_string_for_key?(key, value)
      return true if string_too_long?(value)
      urlish = URL_KEYS.include?(key.to_s) || key.to_s.end_with?("_uri", "_url")
      return true if urlish && !valid_url?(value)
      false
    end
  end
end
# :nocov:
