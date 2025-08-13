# frozen_string_literal: true

# GemMine: Generic gem scaffold generator for benchmarking and test fixtures.
#
# Usage (one-liner):
#   GemMine.factory(count: 30)
#
module GemMine
  autoload :Generator, "gem_mine/generator"
  autoload :Helpers,   "gem_mine/helpers"

  # Factory entry point to generate a collection of gem scaffolds.
  # Options may be provided as static values or callables (Proc/Lambda) that
  # receive a per-gem context hash. See GemMine::Generator for full API.
  def self.factory(options = {})
    Generator.new(options).run
  end
end
