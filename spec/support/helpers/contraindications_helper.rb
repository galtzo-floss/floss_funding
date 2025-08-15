# frozen_string_literal: true

# Test helper to control global contraindications deterministically in specs.
#
# Idempotent: can be called multiple times within an example; later calls
# override earlier stubs. Call with no args to apply defaults (no
# contraindications; STDOUT.tty? => true).
#
# Usage examples:
#   configure_contraindications!                                   # defaults
#   configure_contraindications!(poke: { ci: true })               # CI=true
#   configure_contraindications!(poke: { pwd_raises: true })
#   configure_contraindications!(at_exit: { stdout_tty: true,
#                                            configurations: cfg })
#   # Override later in the same example
#   configure_contraindications!(at_exit: { constants_silent: true })
#
# Note: If rspec-stubbed_env is available (stub_env), it will be used
# to control ENV safely; otherwise ENV will be set directly.
module ContraIndicationsSpecHelper
  DEFAULTS = {
    :poke => {
      :ci => false,
      :pwd_raises => false,
      :stdout_tty => true,
    },
    :at_exit => {
      :stdout_tty => true,
    },
  }.freeze

  # Deep merge utility for small Hash shapes
  def _deep_merge(a, b)
    return a unless b && !b.empty?
    a.merge(b) do |_k, av, bv|
      if av.is_a?(Hash) && bv.is_a?(Hash)
        _deep_merge(av, bv)
      else
        bv
      end
    end
  end

  def configure_contraindications!(opts = {})
    cfg = _deep_merge(DEFAULTS, opts || {})

    # Poke contraindications
    # FlossFunding.silenced for early short-circuit
    if cfg[:poke].key?(:global_silenced)
      allow(FlossFunding).to receive(:silenced).and_return(!!cfg[:poke][:global_silenced])
    end

    # ENV["CI"]
    ci_val = cfg[:poke][:ci]
    if respond_to?(:stub_env)
      stub_env("CI" => ci_val ? "true" : "false")
    else
      ENV["CI"] = ci_val ? "true" : "false"
    end

    # Dir.pwd raised?
    if cfg[:poke][:pwd_raises]
      allow(Dir).to receive(:pwd).and_raise(StandardError)
    end

    # STDOUT tty? for poke path
    if cfg[:poke].key?(:stdout_tty)
      allow(STDOUT).to receive(:tty?).and_return(!!cfg[:poke][:stdout_tty])
    end

    # At-exit contraindications
    if cfg[:at_exit].key?(:global_silenced)
      allow(FlossFunding).to receive(:silenced).and_return(!!cfg[:at_exit][:global_silenced])
    end

    if cfg[:at_exit].key?(:constants_silent)
      stub_const("FlossFunding::Constants::SILENT", !!cfg[:at_exit][:constants_silent])
    end

    if cfg[:at_exit].key?(:stdout_tty)
      allow(STDOUT).to receive(:tty?).and_return(!!cfg[:at_exit][:stdout_tty])
    end

    if cfg[:at_exit].key?(:configurations)
      allow(FlossFunding).to receive(:configurations).and_return(cfg[:at_exit][:configurations])
    end

    true
  end

  alias_method :reset_contraindications!, :configure_contraindications!
end

RSpec.configure do |config|
  config.include ContraIndicationsSpecHelper
  # Apply default, no-contraindications configuration before every example.
  # Individual examples may call configure_contraindications! again to override.
  config.before do
    configure_contraindications!
  end
end
