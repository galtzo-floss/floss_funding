# frozen_string_literal: true

# Explicitly require the Check module since it's lazy loaded
require "floss_funding/check"

RSpec.describe FlossFunding::Check do
  # Create a test class that extends the Check module
  let(:test_class) do
    Class.new do
      extend FlossFunding::Check
    end
  end

  describe "class methods" do
    it "sets now_time when included" do
      test_time = Time.new(2025, 8, 8)
      test_module = Module.new
      described_class.included(test_module, test_time)
      expect(FlossFunding::Check::ClassMethods.now_time).to eq(test_time)
    end

    it "sets now_time when extended" do
      test_time = Time.new(2025, 8, 8)
      test_module = Module.new
      described_class.extended(test_module, test_time)
      expect(FlossFunding::Check::ClassMethods.now_time).to eq(test_time)
    end
  end

  describe "Namespace crypto helpers" do
    it "returns false for empty activation key" do
      ns = FlossFunding::Namespace.new("namespace")
      expect(ns.floss_funding_decrypt("")).to be(false)
    end

    it "attempts to decrypt a valid activation key" do
      # Since we can't easily test actual decryption without a valid key,
      # we'll test that it calls the expected methods
      cipher_double = instance_double(OpenSSL::Cipher)
      allow(OpenSSL::Cipher).to receive(:new).and_return(cipher_double)
      allow(cipher_double).to receive_messages(:decrypt => cipher_double, :update => "decrypted", :final => " text")
      allow(cipher_double).to receive(:key=)

      # Valid hex string of length 64
      activation_key = "a" * 64
      ns = FlossFunding::Namespace.new("TestNamespace")

      expect(ns.floss_funding_decrypt(activation_key)).to eq("decrypted text")
    end

    it "check_unpaid_silence works with namespace-specific key formats" do
      ns = FlossFunding::Namespace.new("Quantum::Mechanics")
      expect(ns.check_unpaid_silence(FlossFunding::FREE_AS_IN_BEER)).to be(true)
      expect(ns.check_unpaid_silence(FlossFunding::BUSINESS_IS_NOT_GOOD_YET)).to be(true)
      expect(ns.check_unpaid_silence(FlossFunding::NOT_FINANCIALLY_SUPPORTING)).to be(false)
      expect(ns.check_unpaid_silence("#{FlossFunding::NOT_FINANCIALLY_SUPPORTING}-Quantum::Mechanics")).to be(true)
      expect(ns.check_unpaid_silence("some-other-key")).to be(false)
    end
  end

  describe "#base_words" do
    it "calls FlossFunding.base_words with an Integer" do
      allow(FlossFunding).to receive(:base_words).with(Integer).and_return([])
      test_class.base_words
      expect(FlossFunding).to have_received(:base_words).with(Integer)
    end
  end

  describe "#check_activation" do
    it "returns true when plain_text is found in base_words" do
      allow(test_class).to receive(:base_words).and_return(["word1", "word2", "word3"])
      expect(test_class.check_activation("word2")).to be(true)
    end

    it "returns false when plain_text is not found in base_words" do
      allow(test_class).to receive(:base_words).and_return(["word1", "word2", "word3"])
      expect(test_class.check_activation("word4")).to be(false)
    end
  end

  describe "#floss_funding_initiate_begging" do
    let(:namespace) { "TestNamespace" }
    let(:env_var_name) { FlossFunding::UnderBar.env_variable_name(namespace) }
    let(:gem_name) { "papa_bear" }

    def event_for(activation_key, state)
      library = instance_double(FlossFunding::Library, :namespace => namespace, :gem_name => gem_name)
      FlossFunding::ActivationEvent.new(library, activation_key, state, nil)
    end

    context "with unactivated state (empty key)" do
      it "calls start_begging" do
        allow(test_class).to receive(:start_begging).with(namespace, env_var_name, gem_name)
        evt = event_for("", FlossFunding::STATES[:unactivated])
        test_class.floss_funding_initiate_begging(evt)
        expect(test_class).to have_received(:start_begging).with(namespace, env_var_name, gem_name)
      end
    end

    context "with invalid state" do
      it "calls start_coughing" do
        invalid_key = "not-a-hex-key"
        allow(test_class).to receive(:start_coughing).with(invalid_key, namespace, env_var_name)
        evt = event_for(invalid_key, FlossFunding::STATES[:invalid])
        test_class.floss_funding_initiate_begging(evt)
        expect(test_class).to have_received(:start_coughing).with(invalid_key, namespace, env_var_name)
      end
    end

    context "with activated state" do
      it "returns nil without begging or coughing" do
        allow(test_class).to receive(:start_begging)
        allow(test_class).to receive(:start_coughing)
        evt = event_for("whatever", FlossFunding::STATES[:activated])
        result = test_class.floss_funding_initiate_begging(evt)
        expect(result).to be_nil
        expect(test_class).not_to have_received(:start_begging)
        expect(test_class).not_to have_received(:start_coughing)
      end
    end
  end

  describe "#start_coughing" do
    it "outputs the expected message", :aggregate_failures do
      activation_key = "invalid-key"
      namespace = "TestNamespace"
      env_var_name = "TEST_NAMESPACE"

      output = capture(:stdout) do
        test_class.send(:start_coughing, activation_key, namespace, env_var_name)
      end

      expect(output).to include("COUGH, COUGH.")
      expect(output).to include("it appears as though you tried to set an activation key")
      expect(output).to include("Activation Key: #{activation_key}")
      expect(output).to include("Namespace: #{namespace}")
      expect(output).to include("ENV Variable: #{env_var_name}")
      expect(output).to include("Paid activation keys are 8 bytes, 64 hex characters, long")
      expect(output).to include("Yours is #{activation_key.length} characters long")
    end

    it "does not output when global silence is requested" do
      activation_key = "invalid-key"
      namespace = "TestNamespace"
      env_var_name = "TEST_NAMESPACE"

      allow(FlossFunding::ContraIndications).to receive(:at_exit_contraindicated?).and_return(true)

      output = capture(:stdout) do
        test_class.send(:start_coughing, activation_key, namespace, env_var_name)
      end

      expect(output).to eq("")
    end
  end

  describe "#start_begging" do
    let(:gem_name) { "mama_bear" }

    it "outputs a single-line note deferring details to at_exit", :aggregate_failures do
      namespace = "TestNamespace"
      env_var_name = "TEST_NAMESPACE"

      output = capture(:stdout) do
        test_class.send(:start_begging, namespace, env_var_name, gem_name)
      end

      expect(output.strip).to include("FLOSS Funding: Activation key missing for #{gem_name} (#{namespace}).")
      expect(output).to include("ENV[\"#{env_var_name}\"]")
      expect(output).to include("details will be shown at exit")
    end
  end
end
