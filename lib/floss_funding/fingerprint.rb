module FlossFunding
  # A tiny marker module mixed into libraries that include FlossFunding.
  #
  # Exposes a single no-op method so specs (and external diagnostics) can
  # detect that a library has integrated FlossFunding by checking
  # `respond_to?(:floss_funding_fingerprint)`.
  module Fingerprint
    # Returns nil; presence of this method is the signal.
    #
    # @return [nil]
    # @note Test shim: used by specs; no internal usage as of 2025-08-13.
    def floss_funding_fingerprint
      nil
    end
  end
end
