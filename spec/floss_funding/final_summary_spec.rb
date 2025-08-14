# frozen_string_literal: true

RSpec.describe FlossFunding::FinalSummary do
  include_context "with stubbed env"

  before do
    # Ensure clean global state for every example
    FlossFunding.namespaces = {}
    # seed the library’s own namespace as activated to avoid noisy output in unrelated places
    stub_env("FLOSS_FUNDING_FLOSS_FUNDING" => "Free-as-in-beer")
  end

  after do
    FlossFunding.namespaces = {}
  end

  # Helper to register a namespace with one or more events
  def register_ns(name, events)
    ns = FlossFunding::Namespace.new(name)
    ns.activation_events = Array(events)
    # add one event to global list (method appends)
    FlossFunding.add_or_update_namespace_with_event(ns, ns.activation_events.first)
    ns
  end

  # Create a simple event with a minimal library double
  def make_event(ns_name, state, gem_name: nil)
    lib = instance_double("Lib", :namespace => ns_name, :gem_name => gem_name.nil? ? nil : (gem_name || ns_name.downcase))
    FlossFunding::ActivationEvent.new(lib, "", state)
  end

  describe "rendering basics (no namespaces)", :check_output do
    it "prints summary with zero counts and no invalid line or spotlight" do
      fake_pb = instance_double("PB", :increment => nil)
      expect(ProgressBar).to receive(:create).with(:title => "Activated Libraries", :total => 0).and_return(fake_pb)

      output = capture_stdout { described_class.new }
      expect(output).to match(/FLOSS Funding Summary:\nactivated: namespaces=0 \/ libraries=0\nunactivated: namespaces=0 \/ libraries=0/)
      expect(output).not_to match(/invalid: namespaces=/)
      expect(output).not_to match(/Unactivated\/Invalid namespace spotlight:/)
    end
  end

  describe "rendering with activated and unactivated and invalid", :check_output do
    before do
      # Build three namespaces: A(activated), U(unactivated), I(invalid)
      a1 = make_event("NsA", :activated, :gem_name => "gem_a")
      u1 = make_event("NsU", :unactivated, :gem_name => "gem_u")
      i1 = make_event("NsI", :invalid, :gem_name => "gem_i")

      @ns_a = register_ns("NsA", [a1])
      @ns_u = register_ns("NsU", [u1])
      @ns_i = register_ns("NsI", [i1])

      # Deterministic spotlight: force the random pick to choose @ns_u
      allow_any_instance_of(described_class).to receive(:random_unpaid_or_invalid_namespace).and_return(@ns_u)

      # Stub configurations to contain default values for each ns
      default_cfg = FlossFunding::Configuration.new({
        "floss_funding_url" => ["https://example.invalid/f"],
        "suggested_donation_amount" => [42],
        "gem_name" => ["g"],
      })
      allow(FlossFunding).to receive(:configurations).and_return({
        "NsA" => [default_cfg],
        "NsU" => [default_cfg],
        "NsI" => [default_cfg],
      })

      # Silence the progressbar’s own console output; we only verify it is created and increments
      @fake_pb = instance_double("PB", :increment => nil)
      expect(ProgressBar).to receive(:create).with(:title => "Activated Libraries", :total => 3).and_return(@fake_pb)
      # Expect it to increment exactly for activated libraries (1 time)
      expect(@fake_pb).to receive(:increment).once
    end

    it "prints spotlight for chosen ns and shows counts including invalid" do
      output = capture_stdout { described_class.new }

      # spotlight section for @ns_u
      expect(output).to include("Unactivated/Invalid namespace spotlight:")
      expect(output).to include("- Namespace: NsU")
      expect(output).to include("ENV Variable: FLOSS_FUNDING_NS_U")
      # libraries list appears when non-empty
      expect(output).to match(/Libraries: (gem_u|nsu)/)
      # configuration-driven values
      expect(output).to include("Suggested donation amount: $42")
      expect(output).to include("Funding URL: https://example.invalid/f")
      # opt-out key format
      expect(output).to include("Opt-out key: \"Not-financially-supporting-NsU\"")

      # summary counts
      expect(output).to include("FLOSS Funding Summary:")
      expect(output).to include("activated: namespaces=1 / libraries=1")
      expect(output).to include("unactivated: namespaces=1 / libraries=1")
      expect(output).to include("invalid: namespaces=1 / libraries=1")
    end
  end

  describe "invalid line suppression (no invalid events)", :check_output do
    it "omits invalid line when there are zero invalid namespaces and libraries" do
      u1 = make_event("OnlyU", :unactivated, :gem_name => "gem_u")
      register_ns("OnlyU", [u1])

      allow(FlossFunding).to receive(:configurations).and_return({"OnlyU" => [FlossFunding::Configuration.new({})]})

      fake_pb = instance_double("PB", :increment => nil)
      expect(ProgressBar).to receive(:create).with(:title => "Activated Libraries", :total => 1).and_return(fake_pb)

      output = capture_stdout { described_class.new }
      expect(output).to include("unactivated: namespaces=1 / libraries=1")
      expect(output).not_to include("invalid: namespaces=")
    end
  end

  describe "uses defaults when configuration missing or non-hashlike", :check_output do
    it "falls back to default URL and amount and omits empty libraries line" do
      ev = make_event("CfgLess", :unactivated, :gem_name => nil)
      ns = register_ns("CfgLess", [ev])

      # Return a weird configuration object that causes rescue to [] in details lookup
      allow(FlossFunding).to receive(:configurations).and_return({"CfgLess" => [Object.new]})

      # Deterministic spotlight pick to see details
      allow_any_instance_of(described_class).to receive(:random_unpaid_or_invalid_namespace).and_return(ns)

      fake_pb = instance_double("PB", :increment => nil)
      expect(ProgressBar).to receive(:create).with(:title => "Activated Libraries", :total => 1).and_return(fake_pb)

      output = capture_stdout { described_class.new }
      expect(output).to include("Funding URL: https://floss-funding.dev")
      expect(output).to include("Suggested donation amount: $5")
      # library gem_name was nil; libraries list should be omitted
      expect(output).not_to include("Libraries:")
    end
  end

  describe "exception safety" do
    it "swallows unexpected errors during render" do
      # Having something explode, e.g., the progressbar creation
      allow(ProgressBar).to receive(:create).and_raise(StandardError.new("boom"))
      expect { described_class.new }.not_to raise_error
    end
  end

  # Small helper to capture stdout while keeping :check_output opt-in behavior consistent
  def capture_stdout
    old = $stdout
    sio = StringIO.new
    $stdout = sio
    yield
    sio.string
  ensure
    $stdout = old
  end
end
