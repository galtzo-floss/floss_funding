# frozen_string_literal: true

require "securerandom"

RSpec.describe FlossFunding::Library do
  let(:including_path) { __FILE__ }
  let(:namespace) { FlossFunding::Namespace.new("TestModule") }

  it "sets silence when :silent is a callable" do
    root_path = FlossFunding::FF_ROOT
    config_path = FlossFunding::FF_ROOT
    including_path = __FILE__
    config = FlossFunding::Configuration.new({"library_name" => "TestModule"})
    callable = -> { true }

    lib = described_class.new(config["TestModule"], namespace, nil, "TestModule", including_path, root_path, config_path, namespace.env_var_name, config, callable)

    expect(lib.silence).to eq(callable)
  end
end
