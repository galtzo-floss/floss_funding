#!/usr/bin/env ruby
# frozen_string_literal: true

# Add the lib directory to the load path
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

# Load the Check module
require "floss_funding/check"

# Create a test module
module TestModule
  module InnerModule
  end
end

# Current time
current_time = Time.now

# Extend the test module with the Check module, passing current time
FlossFunding::Check.extended(TestModule::InnerModule, current_time)

# Check if the methods are available
puts "Methods available on TestModule::InnerModule:"
puts TestModule::InnerModule.methods.grep(/floss_funding/).inspect

# Try to call the method
begin
  namespace = "TestNamespace"
  env_var_name = "TEST_NAMESPACE"
  activation_key = ""
  TestModule::InnerModule.floss_funding_initiate_begging(activation_key, namespace, env_var_name)
  puts "Successfully called floss_funding_initiate_begging"
rescue => e
  puts "Error calling floss_funding_initiate_begging: #{e.message}"
end
