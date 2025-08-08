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

  describe "#floss_funding_decrypt" do
    it "returns false for empty license key" do
      expect(test_class.floss_funding_decrypt("", "namespace")).to be(false)
    end

    it "attempts to decrypt a valid license key" do
      # Since we can't easily test actual decryption without a valid key,
      # we'll test that it calls the expected methods
      cipher_double = instance_double(OpenSSL::Cipher)
      allow(OpenSSL::Cipher).to receive(:new).and_return(cipher_double)
      allow(cipher_double).to receive_messages(:decrypt => cipher_double, :update => "decrypted", :final => " text")
      allow(cipher_double).to receive(:key=)

      # Valid hex string of length 64
      license_key = "a" * 64
      namespace = "TestNamespace"

      expect(test_class.floss_funding_decrypt(license_key, namespace)).to eq("decrypted text")
    end
  end

  describe "#check_unpaid_silence" do
    it "returns true for FREE_AS_IN_BEER license key" do
      expect(test_class.check_unpaid_silence(FlossFunding::FREE_AS_IN_BEER, "Dog")).to be(true)
    end

    it "returns true for BUSINESS_IS_NOT_GOOD_YET license key" do
      expect(test_class.check_unpaid_silence(FlossFunding::BUSINESS_IS_NOT_GOOD_YET, "Dog")).to be(true)
    end

    it "returns false for NOT_FINANCIALLY_SUPPORTING license key" do
      expect(test_class.check_unpaid_silence(FlossFunding::NOT_FINANCIALLY_SUPPORTING, "Dog")).to be(false)
    end

    it "returns true for NOT_FINANCIALLY_SUPPORTING-namespace format" do
      expect(test_class.check_unpaid_silence("#{FlossFunding::NOT_FINANCIALLY_SUPPORTING}-Quantum::Mechanics", "Quantum::Mechanics")).to be(true)
    end

    it "returns false for other license keys" do
      expect(test_class.check_unpaid_silence("some-other-key", "Dog")).to be(false)
    end
  end

  describe "#base_words" do
    it "calls FlossFunding.base_words with an Integer" do
      allow(FlossFunding).to receive(:base_words).with(Integer).and_return([])
      test_class.base_words
      expect(FlossFunding).to have_received(:base_words).with(Integer)
    end
  end

  describe "#check_license" do
    it "returns true when plain_text is found in base_words" do
      allow(test_class).to receive(:base_words).and_return(["word1", "word2", "word3"])
      expect(test_class.check_license("word2")).to be(true)
    end

    it "returns false when plain_text is not found in base_words" do
      allow(test_class).to receive(:base_words).and_return(["word1", "word2", "word3"])
      expect(test_class.check_license("word4")).to be(false)
    end
  end

  describe "#floss_funding_initiate_begging" do
    let(:namespace) { "TestNamespace" }
    let(:env_var_name) { "TEST_NAMESPACE" }

    context "with empty license key" do
      it "calls start_begging" do
        allow(test_class).to receive(:start_begging).with(namespace, env_var_name)
        test_class.floss_funding_initiate_begging("", namespace, env_var_name)
        expect(test_class).to have_received(:start_begging).with(namespace, env_var_name)
      end
    end

    context "with unpaid silence license key" do
      it "returns nil without begging", :aggregate_failures do
        allow(test_class).to receive(:check_unpaid_silence).with(FlossFunding::FREE_AS_IN_BEER, "TestNamespace").and_return(true)
        allow(test_class).to receive(:start_begging)
        allow(test_class).to receive(:start_coughing)

        result = test_class.floss_funding_initiate_begging(FlossFunding::FREE_AS_IN_BEER, namespace, env_var_name)

        expect(test_class).to have_received(:check_unpaid_silence).with(FlossFunding::FREE_AS_IN_BEER, "TestNamespace")
        expect(test_class).not_to have_received(:start_begging)
        expect(test_class).not_to have_received(:start_coughing)
        expect(result).to be_nil
      end
    end

    context "with invalid hex license key" do
      it "calls start_coughing" do
        invalid_key = "not-a-hex-key"
        allow(test_class).to receive(:check_unpaid_silence).with(invalid_key, "TestNamespace").and_return(false)
        allow(test_class).to receive(:start_coughing).with(invalid_key, namespace, env_var_name)

        test_class.floss_funding_initiate_begging(invalid_key, namespace, env_var_name)

        expect(test_class).to have_received(:check_unpaid_silence).with(invalid_key, "TestNamespace")
        expect(test_class).to have_received(:start_coughing).with(invalid_key, namespace, env_var_name)
      end
    end

    context "with valid hex license key but invalid after decryption" do
      it "calls start_begging", :aggregate_failures do
        valid_hex_key = "a" * 64
        allow(test_class).to receive(:check_unpaid_silence).with(valid_hex_key, namespace).and_return(false)
        allow(test_class).to receive(:floss_funding_decrypt).with(valid_hex_key, namespace).and_return("decrypted")
        allow(test_class).to receive(:check_license).with("decrypted").and_return(false)
        allow(test_class).to receive(:start_begging).with(namespace, env_var_name)

        test_class.floss_funding_initiate_begging(valid_hex_key, namespace, env_var_name)

        expect(test_class).to have_received(:check_unpaid_silence).with(valid_hex_key, namespace)
        expect(test_class).to have_received(:floss_funding_decrypt).with(valid_hex_key, namespace)
        expect(test_class).to have_received(:check_license).with("decrypted")
        expect(test_class).to have_received(:start_begging).with(namespace, env_var_name)
      end
    end

    context "with valid hex license key and valid after decryption" do
      it "returns nil without begging", :aggregate_failures do
        # A valid license key for
        #   namespace: "Testing::Flavors::Of::Ice::Cream"
        #   ENV var: "TESTING_FLAVORS_OF_ICE_CREAM"
        #   Month: 2225-07
        # is:
        #   D730AA2603ACF6BD2DC78EE3AF6179087E80A10A42CCA85D6ED06F90F7FE9CF3
        namespace = "Testing::Flavors::Of::Ice::Cream"
        env_var_name = "TESTING_FLAVORS_OF_ICE_CREAM"
        valid_hex_key = "D730AA2603ACF6BD2DC78EE3AF6179087E80A10A42CCA85D6ED06F90F7FE9CF3"
        result = nil

        back_to_the_future = Time.local(2225, 7, 7, 7, 7, 7)
        Timecop.freeze(back_to_the_future) do
          result = test_class.floss_funding_initiate_begging(valid_hex_key, namespace, env_var_name)
        end

        expect(result).to be_nil
      end
    end
  end

  describe "#start_coughing" do
    it "outputs the expected message", :aggregate_failures do
      license_key = "invalid-key"
      namespace = "TestNamespace"
      env_var_name = "TEST_NAMESPACE"

      output = capture(:stdout) do
        test_class.send(:start_coughing, license_key, namespace, env_var_name)
      end

      expect(output).to include("COUGH, COUGH.")
      expect(output).to include("using #{namespace} for free")
      expect(output).to include("License Key: #{license_key}")
      expect(output).to include("Namespace: #{namespace}")
      expect(output).to include("ENV Variable: #{env_var_name}")
      expect(output).to include("Paid license keys are 64 characters long")
      expect(output).to include("Yours is #{license_key.length} characters long")
    end
  end

  describe "#start_begging" do
    it "outputs the expected message", :aggregate_failures do
      namespace = "TestNamespace"
      env_var_name = "TEST_NAMESPACE"

      output = capture(:stdout) do
        test_class.send(:start_begging, namespace, env_var_name)
      end

      expect(output).to include("Unremunerated use of #{namespace} detected!")
      expect(output).to include("FlossFunding (https://floss-funding.dev)")
      expect(output).to include("ENV[\"#{env_var_name}\"]")
      expect(output).to include(FlossFunding::FREE_AS_IN_BEER)
      expect(output).to include(FlossFunding::BUSINESS_IS_NOT_GOOD_YET)
      expect(output).to include(FlossFunding::NOT_FINANCIALLY_SUPPORTING)
    end
  end

  describe "#footer" do
    it "includes the version number" do
      footer = test_class.send(:footer)
      expect(footer).to include("FlossFunding v#{FlossFunding::Version::VERSION}")
    end

    it "includes the expected message" do
      footer = test_class.send(:footer)
      expect(footer).to include("Please buy FLOSS licenses to support open source developers.")
    end
  end
end
