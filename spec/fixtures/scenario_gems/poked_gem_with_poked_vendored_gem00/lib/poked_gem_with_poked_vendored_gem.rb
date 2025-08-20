# frozen_string_literal: true
module PokedGemWithPokedVendoredGem
  module Core; end
end
require "floss_funding"
PokedGemWithPokedVendoredGem::Core.send(:include, FlossFunding::Poke.new(__FILE__, namespace: "PokedGemWithPokedVendoredGem"))
# Require the vendored gem
require_relative "../vendor/vendored_gem/lib/vendored_gem"
