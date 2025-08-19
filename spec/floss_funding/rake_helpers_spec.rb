# frozen_string_literal: true

RSpec.describe FlossFunding::RakeHelpers do
  include_context "with stubbed env"

  describe "::show_diff", :check_output do
    let(:old_s) { "a\nb\nc\n" }
    let(:new_s) { "a\nbeta\nc\n" }

    it "prints diff headers" do
      out = capture(:stdout) { described_class.show_diff(old_s, new_s) }
      expect(out).to include("--- current")
    end

    it "prints new header" do
      out = capture(:stdout) { described_class.show_diff(old_s, new_s) }
      expect(out).to include("+++ new")
    end

    it "prints removed line", :check_output do
      out = capture(:stdout) { described_class.show_diff(old_s, new_s) }
      expect(out).to include("- b")
    end

    it "prints added line", :check_output do
      out = capture(:stdout) { described_class.show_diff(old_s, new_s) }
      expect(out).to include("+ beta")
    end
  end

  describe "::ensure_gitignore_sentinels" do
    let(:header) { "# Sentinels" }
    let(:lock) { ".floss_funding.*.lock" }

    it "previews a diff when adding a section", :check_output do
      Dir.mktmpdir do |dir|
        gi = File.join(dir, ".gitignore")
        File.write(gi, "existing\n")
        stub_env("FF_INSTALL_CHOICE" => "append")
        out = capture(:stdout) { described_class.ensure_gitignore_sentinels(gi, header, lock) }
        expect(out).to include("--- current")
      end
    end

    it "adds a section when not present and append chosen" do
      Dir.mktmpdir do |dir|
        gi = File.join(dir, ".gitignore")
        File.write(gi, "existing\n")
        stub_env("FF_INSTALL_CHOICE" => "append")
        described_class.ensure_gitignore_sentinels(gi, header, lock)
        expect(File.read(gi)).to include("existing\n\n# Sentinels\n.floss_funding.*.lock\n")
      end
    end

    it "auto-skips without prompting when section contains the lock line already (no prompt)" do
      Dir.mktmpdir do |dir|
        gi = File.join(dir, ".gitignore")
        initial = ["# Sentinels", ".floss_funding.*.lock", "# Next"].join("\n") + "\n"
        File.write(gi, initial)
        allow($stdin).to receive(:gets).and_raise("no prompt expected")
        expect { described_class.ensure_gitignore_sentinels(gi, header, lock) }.not_to raise_error
      end
    end

    it "auto-skips without prompting when section contains the lock line already (no change)" do
      Dir.mktmpdir do |dir|
        gi = File.join(dir, ".gitignore")
        initial = ["# Sentinels", ".floss_funding.*.lock", "# Next"].join("\n") + "\n"
        File.write(gi, initial)
        allow($stdin).to receive(:gets).and_raise("no prompt expected")
        described_class.ensure_gitignore_sentinels(gi, header, lock)
        expect(File.read(gi)).to eq(initial)
      end
    end
  end
end
