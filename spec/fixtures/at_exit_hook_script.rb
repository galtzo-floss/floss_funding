# frozen_string_literal: true

# This script is executed in a real Ruby subprocess by specs to validate
# the new at_exit hook behavior. It loads the library and triggers one
# namespace inclusion event to give the summary something to report.

# Force TTY to ensure at_exit output is not contraindicated in this subprocess
class << STDOUT
  def tty?
    true
  end
end

require "floss_funding"

# Create a dummy namespace and include the Poke module to simulate usage
module MiniAtExitTest
  module Inner; end
end

MiniAtExitTest::Inner.send(:include, FlossFunding::Poke.new(__FILE__, :wedge => true))

# Let the process exit normally; the at_exit hook should render the summary.
