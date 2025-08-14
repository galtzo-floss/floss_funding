# frozen_string_literal: true

RSpec.describe FlossFunding::UnderBar do
  describe ".to_under_bar" do
    context "with valid inputs" do
      it "converts PascalCase to PASCAL_CASE" do
        expect(described_class.to_under_bar("PascalCase")).to eq("PASCAL_CASE")
      end

      it "converts camelCase to CAMEL_CASE" do
        expect(described_class.to_under_bar("camelCase")).to eq("CAMEL_CASE")
      end

      it "handles single word uppercase" do
        expect(described_class.to_under_bar("WORD")).to eq("W_O_R_D")
      end

      it "handles single word lowercase" do
        expect(described_class.to_under_bar("word")).to eq("WORD")
      end

      it "handles numbers" do
        expect(described_class.to_under_bar("Word123")).to eq("WORD123")
      end

      it "removes leading underscore if present", :aggregate_failures do
        # This test simulates what happens when an uppercase letter is at the beginning
        # and gets converted to an underscore + letter
        input = "Word"
        with_underscore = "_Word"
        # Manually apply the SUBBER_UNDER transformation
        transformed = with_underscore.gsub(described_class::SUBBER_UNDER) { "_#{$1}" }
        # Verify our test setup is correct
        expect(transformed).to eq("__Word")
        # Now verify the method correctly removes the leading underscore
        expect(described_class.to_under_bar(input)).to eq("WORD")
      end
    end

    context "with invalid inputs" do
      it "raises an error for strings with special characters" do
        expect {
          described_class.to_under_bar("Invalid@String")
        }.to raise_error(FlossFunding::Error, /Invalid! Each part of klass name must match/)
      end

      it "raises an error for strings longer than 256 characters" do
        long_string = "A" * 257
        expect {
          described_class.to_under_bar(long_string)
        }.to raise_error(FlossFunding::Error, /Invalid! Each part of klass name must match/)
      end

      it "raises an error for empty strings" do
        expect {
          described_class.to_under_bar("")
        }.to raise_error(FlossFunding::Error, /Invalid! Each part of klass name must match/)
      end

      it "raises an error for nil" do
        expect {
          described_class.to_under_bar(nil)
        }.to raise_error(NoMethodError)
      end

      it "raises an error for strings with colons" do
        expect {
          described_class.to_under_bar("Word:Colon")
        }.to raise_error(FlossFunding::Error, /Invalid! Each part of klass name must match/)
      end
    end
  end

  describe ".env_variable_name" do
    # Stub test classes
    before do
      # Stub test classes in different namespaces
      test_class = Class.new
      nested_class = Class.new
      nested_module = Module.new

      stub_const("TestModule", Module.new)
      stub_const("TestModule::TestClass", test_class)
      stub_const("TestModule::NestedModule", nested_module)
      stub_const("TestModule::NestedModule::NestedClass", nested_class)
    end

    context "with valid inputs" do
      it "converts a simple class name to an environment variable name" do
        expect(described_class.env_variable_name(TestModule::TestClass.name)).to eq("FLOSS_FUNDING_TEST_MODULE_TEST_CLASS")
      end

      it "handles nested namespaces" do
        expect(described_class.env_variable_name(TestModule::NestedModule::NestedClass.name)).to eq("FLOSS_FUNDING_TEST_MODULE_NESTED_MODULE_NESTED_CLASS")
      end

      it "works with Ruby standard library classes" do
        expect(described_class.env_variable_name(String.name)).to eq("FLOSS_FUNDING_STRING")
      end

      it "works with classes that have numbers in their names" do
        stub_const("Test123Class", Class.new)
        expect(described_class.env_variable_name(Test123Class.name)).to eq("FLOSS_FUNDING_TEST123_CLASS")
      end

      it "works when klass is a string from a module" do
        expect(described_class.env_variable_name(TestModule.name)).to eq("FLOSS_FUNDING_TEST_MODULE")
      end

      it "works when klass a namespace-like string" do
        expect(described_class.env_variable_name("NotAClass")).to eq("FLOSS_FUNDING_NOT_A_CLASS")
      end

      it "accepts a Namespace object and uses its env_var_name" do
        ns = FlossFunding::Namespace.new("Alpha")
        expect(described_class.env_variable_name(ns)).to eq(ns.env_var_name)
      end

      it "reset_cache! clears memoized names so prefix changes are reflected" do
        described_class.reset_cache!
        stub_const("FlossFunding::Constants::DEFAULT_PREFIX", "FUNDING_")
        name1 = described_class.env_variable_name("FooBar")
        expect(name1).to eq("FUNDING_FOO_BAR")

        # Change the prefix; without reset it should still return cached value
        stub_const("FlossFunding::Constants::DEFAULT_PREFIX", "DIFF_")
        name2 = described_class.env_variable_name("FooBar")
        expect(name2).to eq("FUNDING_FOO_BAR")

        # After reset, recomputation should use the new prefix
        described_class.reset_cache!
        name3 = described_class.env_variable_name("FooBar")
        expect(name3).to eq("DIFF_FOO_BAR")
      end
    end

    context "with invalid inputs" do
      it "raises an error when klass is nil" do
        expect {
          described_class.env_variable_name(:klass => nil)
        }.to raise_error(FlossFunding::Error, /namespace must be a String/)
      end
    end
  end
end
