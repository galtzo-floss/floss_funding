# frozen_string_literal: true

RSpec.describe FlossFunding do
  it "adds the rakelib directory without error" do
    require "rake"
    expect {
      require "floss_funding/tasks"
    }.not_to raise_error
  end
end
