# frozen_string_literal: true

# This spec tests RSpec configuration behavior, not a specific class
# rubocop:disable RSpec/DescribeClass
RSpec.describe "check_output tag" do
  context "with :check_output tag" do
    it "does not silence STDOUT", :check_output do |example|
      # This output should be visible
      puts "This output should be visible"
      expect(example.metadata[:check_output]).to be(true)
    end
  end

  context "without :check_output tag" do
    it "silences STDOUT" do |example|
      # This output should be silenced
      puts "This output should be silenced"
      expect(example.metadata[:check_output]).to be_nil
    end
  end
end
# rubocop:enable RSpec/DescribeClass
