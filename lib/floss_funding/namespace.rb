# frozen_string_literal: true

module FlossFunding
  # Represents a logical namespace that groups activation events across one or more libraries
  # sharing the same namespace string. It mainly serves as a container for ActivationEvent
  # instances recorded for that namespace.
  class Namespace
    # @return [String, nil]
    attr_reader :name
    # @return [String]
    attr_reader :env_var_name
    # @return [String]
    attr_reader :activation_key
    # @return [String]
    attr_reader :state
    # @return [Array<FlossFunding::ActivationEvent>]
    attr_reader :activation_events

    # Initialize a Namespace container.
    #
    # @param name [String] the namespace string this object represents
    # @param base [Module] the including module that provides check_activation
    # @param activation_events [Array<FlossFunding::ActivationEvent>] initial events (defaults to empty)
    def initialize(name, base = nil, activation_events = [])
      raise ArgumentError, "name must be a String" unless name.is_a?(String)

      @name = name
      @env_var_name = ::FlossFunding::UnderBar.env_variable_name(name)
      @activation_key = ENV.fetch(@env_var_name, "")

      # Determine the initial state for this namespace based on its activation key
      @state = begin
        if @activation_key.empty?
          ::FlossFunding::STATES[:unactivated]
        elsif check_unpaid_silence(@activation_key)
          ::FlossFunding::STATES[:activated]
        elsif !(@activation_key =~ ::FlossFunding::HEX_LICENSE_RULE)
          ::FlossFunding::STATES[:invalid]
        else
          plain_text = floss_funding_decrypt(@activation_key)
          if ::FlossFunding.check_activation(plain_text)
            ::FlossFunding::STATES[:activated]
          else
            ::FlossFunding::DEFAULT_STATE
          end
        end
      end

      self.activation_events = activation_events
    end

    def to_s
      name
    end

    def has_state?(state)
      !activation_events.detect { |ae| ae.state == state }.nil?
    end

    def with_state(state)
      activation_events.select { |ae| ae.state == state }
    end

    # @return [Array<FlossFunding::Configuration>]
    def configs
      @activation_events.map(&:library).map(&:config)
    end

    # Replace the activation_events array after validating types.
    #
    # @param value [Array<FlossFunding::ActivationEvent>]
    # @return [void]
    def activation_events=(value)
      array = Array(value).compact
      unless array.all? { |e| e.is_a?(::FlossFunding::ActivationEvent) }
        raise ::FlossFunding::Error, "activation_events must be an array of FlossFunding::ActivationEvent"
      end
      @activation_events = array
    end

    # Returns true for unpaid or opted-out activation_key that
    # should not emit any console output (silent success).
    # Otherwise false.
    #
    # @param activation_key [String]
    # @param namespace [String]
    # @return [Boolean]
    def check_unpaid_silence(activation_key)
      return false if activation_key.empty?

      case activation_key
      when ::FlossFunding::FREE_AS_IN_BEER, ::FlossFunding::BUSINESS_IS_NOT_GOOD_YET, "#{::FlossFunding::NOT_FINANCIALLY_SUPPORTING}-#{name}"
        # Configured as unpaid
        true
      else
        # Might be configured as paid
        false
      end
    end

    # Decrypts a hex-encoded activation key using a namespace-derived key.
    #
    # @param activation_key [String] 64-character hex string for paid activation
    # @param namespace [FlossFunding::Namespace, String] the namespace used to derive the cipher key
    # @return [String, false] plaintext activation key (base word) on success; false if empty
    def floss_funding_decrypt(activation_key)
      return false if activation_key.empty?

      cipher = OpenSSL::Cipher.new("aes-256-cbc").decrypt
      # Memoize the MD5 hexdigest for this namespace instance
      @ff_key_digest ||= Digest::MD5.hexdigest(name)
      cipher.key = @ff_key_digest
      s = [activation_key].pack("H*")

      cipher.update(s) + cipher.final
    end

    # Merge all configurations for this namespace into a single Configuration.
    # Concatenates array values for identical keys across configs.
    # @return [::FlossFunding::Configuration]
    def merged_config
      ::FlossFunding::Configuration.merged_config(configs)
    end
  end
end
