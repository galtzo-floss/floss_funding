# frozen_string_literal: true

module FlossFunding
  # Immutable, read-only configuration wrapper for a library/namespace.
  #
  # Normalizes all values to arrays to simplify downstream processing.
  # Provides a hash-like interface for reading values.
  #
  # Examples
  #   cfg = FlossFunding::Configuration.new({"a" => 1, "b" => [2, 3]})
  #   cfg["a"] #=> [1]
  #   cfg["b"] #=> [2, 3]
  #   cfg.keys   #=> ["a", "b"]
  #   cfg.to_h   #=> {"a"=>[1], "b"=>[2, 3]}
  class Configuration
    include Enumerable

    # Merge an array of Configuration objects into a single Configuration by
    # concatenating array values for identical keys. Assumes each input
    # configuration has already normalized values to arrays.
    # @param cfgs [Array<FlossFunding::Configuration>]
    # @return [FlossFunding::Configuration]
    def self.merged_config(cfgs)
      cfgs = Array(cfgs).compact
      return ::FlossFunding::Configuration.new({}) if cfgs.empty?

      merged = {}
      cfgs.each do |cfg|
        next unless cfg.respond_to?(:each)
        cfg.each do |k, v|
          merged[k.to_s] ||= []
          merged[k.to_s].concat(Array(v))
        end
      end
      ::FlossFunding::Configuration.new(merged)
    end

    # Build from a hash-like object. Keys are converted to Strings, values to Arrays.
    # @param data [Hash]
    def initialize(data = {})
      normalized = {}
      (data || {}).each do |k, v|
        normalized[k.to_s] = ::FlossFunding::Config.normalize_to_array(v)
      end
      @data = normalized.freeze
      freeze
    end

    # Fetch the array value for the given key; returns [] when the key is missing.
    # @param key [String, Symbol]
    # @return [Array]
    def [](key)
      @data[key.to_s] || []
    end

    # Fetch with default/blk compatibility; mirrors Hash#fetch for read-only access.
    def fetch(key, default = nil, &block)
      if @data.key?(key.to_s)
        @data[key.to_s]
      elsif block
        yield(key)
      else
        default
      end
    end

    # Iterate over key, value pairs (values are arrays)
    def each(&block)
      return enum_for(:each) unless block_given?
      @data.each(&block)
    end

    # @return [Array<String>]
    def keys
      @data.keys
    end

    # @return [Boolean]
    def key?(key)
      @data.key?(key.to_s)
    end
    alias_method :include?, :key?
    alias_method :has_key?, :key?

    # @return [Hash{String=>Array}]
    def to_h
      # Already frozen; dup to prevent external mutation of internal state
      @data.dup
    end

    # @return [Integer]
    def size
      @data.size
    end

    # @return [Boolean]
    def empty?
      @data.empty?
    end
  end
end
