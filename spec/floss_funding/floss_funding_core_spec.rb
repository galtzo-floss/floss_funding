# frozen_string_literal: true

# rubocop:disable Style/ClassMethodsDefinitions, RSpec/MultipleExpectations, RSpec/DescribedClass, RSpec/MessageSpies

RSpec.describe FlossFunding do
  include_context "with stubbed env"

  describe "::progress_bar", :check_output do
    it "prints 0% when total is zero (fallback path without progressbar)" do
      allow(Kernel).to receive(:require).with("ruby-progressbar").and_raise(LoadError)
      expect { described_class.progress_bar(0, 0) }.to output(/FUNDED🦷%: 0% \(0\/0\)/).to_stdout
    end

    it "prints counts in non-TTY when progressbar is available" do
      # Provide a minimal ProgressBar implementation
      stub_const("ProgressBar", Class.new do
        def self.create(*)
          new
        end

        def progress=(x)
          @p = x
        end
      end)
      allow($stdout).to receive(:tty?).and_return(false)
      expect { described_class.progress_bar(1, 4) }.to output(/\(1\/4\)/).to_stdout
    end
  end

  describe "::register_wedge error handling" do
    it "captures errors and returns nil without raising" do
      mod = Module.new do
        def self.name
          "ErrMod"
        end
      end
      # Force an error deep inside by making Namespace.new raise
      allow(FlossFunding::Namespace).to receive(:new).and_raise("boom")
      expect(FlossFunding).to receive(:error!).with(kind_of(StandardError), "register_wedge")
      expect(FlossFunding.register_wedge(mod)).to be_nil
    end
  end
end
# rubocop:enable Style/ClassMethodsDefinitions, RSpec/MultipleExpectations, RSpec/DescribedClass, RSpec/MessageSpies
