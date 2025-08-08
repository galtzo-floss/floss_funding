# frozen_string_literal: true

# This script is used by specs to verify the FlossFunding at_exit/END hook output
# It mirrors the inline script previously embedded in the tracking_spec.rb test.

lib = ARGV.shift
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "floss_funding"

# Set ENV so one namespace is treated as licensed (silent)
ENV["FLOSS_FUNDING_TRADITIONAL_TEST_INNER_MODULE"] = FlossFunding::FREE_AS_IN_BEER

# Define two modules and include Poke to trigger tracking
module TraditionalTest
  module InnerModule
    include FlossFunding::Poke
  end
end

module OtherTest
  module InnerModule
    include FlossFunding::Poke
  end
end
# On process exit, FlossFunding's at_exit hook will print the summary
