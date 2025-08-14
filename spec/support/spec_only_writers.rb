# frozen_string_literal: true

# This support module provides writer methods for values that are
# set-once at load in production, but need to be overridden in specs.
# It should only be required from the spec suite.
module FlossFunding
  class << self
    # Allow specs to control the deterministic time source
    attr_writer :loaded_at # rubocop:disable ThreadSafety/ClassAndModuleAttributes

    # Allow specs to override the precomputed month
    attr_writer :loaded_month # rubocop:disable ThreadSafety/ClassAndModuleAttributes

    # Allow specs to override the precomputed number of valid words
    attr_writer :num_valid_words_for_month # rubocop:disable ThreadSafety/ClassAndModuleAttributes
  end
end
