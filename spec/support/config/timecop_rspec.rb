require "timecop/rspec"

# Ensure a consistent time for all tests
#
# Timecop.travel/freeze any RSpec (describe|context|example) with `:travel` or `:freeze` metadata.
#
# ```ruby
# # Timecop.travel
# it "some description", :travel => Time.new(2014, 11, 15) do
#   Time.now # 2014-11-15 00:00:00
#   sleep 6
#   Time.now # 2014-11-15 00:00:06 (6 seconds later)
# end
#
# # Timecop.freeze
# it "some description", :freeze => Time.new(2014, 11, 15) do
#   Time.now # 2014-11-15 00:00:00
#   sleep 6
#   Time.now # 2014-11-15 00:00:00 (Ruby's time hasn't advanced)
# end
# ```
#
GLOBAL_DATE = ENV.fetch("GLOBAL_TIME_TRAVEL_TIME", "2025-08-15") # time starts at midnight on GLOBAL_DATE
ENV["GLOBAL_TIME_TRAVEL_TIME"] ||= GLOBAL_DATE

RSpec.configure do |config|
  config.around do |example|
    Timecop::Rspec.time_machine(:sequential => true).run(example)
  end
end
