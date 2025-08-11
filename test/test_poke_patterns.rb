#!/usr/bin/env ruby
# frozen_string_literal: true

# Add the lib directory to the load path
$LOAD_PATH.unshift(File.expand_path("lib", __dir__))
require "floss_funding"

# Test the traditional usage pattern
module TraditionalTest
  module InnerModule
    # Using the traditional pattern (no custom namespace)
    include FlossFunding::Poke.new(__FILE__)
  end
end

# Test the custom namespace pattern
module CustomTest
  module InnerModule
    # Using the custom namespace pattern
    include FlossFunding::Poke.new(__FILE__, :namespace => "MyNamespace::V4")
  end
end

puts "Test completed successfully!"
puts "The TraditionalTest::InnerModule uses its own name as namespace for FlossFunding"
puts "The CustomTest::InnerModule uses 'MyNamespace::V4' as its namespace for FlossFunding"
