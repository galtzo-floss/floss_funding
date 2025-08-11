require "floss_funding"

# An alternative way to silence FlossFunding for those who are not able to control their ENV variables.
# If this module is loaded before all other gems, then silence will reign.
# This is a less performant way of silencing than setting the global ENV variable.
# Obviously, you could write this code yourself with a different module, and it would accomplish the same thing.
module FlossFunding
  module Silent
    include Poke.new(__FILE__, :silent => true)
  end
end
