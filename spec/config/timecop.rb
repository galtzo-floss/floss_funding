require "timecop"

# Run Tests with a specific time.
#
# Example:
#   back_to_the_future = Time.local(2224, 12, 12, 12, 12, 12)
#   Timecop.freeze(back_to_the_future) do
#     expect("something").to eq("something")
#   end

# turn on safe mode
Timecop.safe_mode = true
