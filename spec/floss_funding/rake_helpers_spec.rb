# frozen_string_literal: true

# rubocop:disable RSpec/MultipleExpectations

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

  describe "::ask_overwrite" do
    it "maps ENV override values to choices without prompting" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "file.txt")
        File.write(path, "x")
        {
          "replace_file" => :replace_file,
          "rf" => :replace_file,
          "overwrite" => :replace_file,
          "append" => :append,
          "p" => :append,
          "skip" => :skip,
          "s" => :skip,
          "abort" => :abort,
          "a" => :abort,
          "diff" => :diff,
          "d" => :diff,
        }.each do |env_val, sym|
          stub_env("FF_INSTALL_CHOICE" => env_val)
          expect(described_class.ask_overwrite(path)).to eq(sym)
        end
      end
    end

    it "accepts default on empty input" do
      allow($stdin).to receive(:gets).and_return("")
      # no ENV set, so it will prompt and then use default
      expect(described_class.ask_overwrite("/tmp/x", :append)).to eq(:append)
    end
  end

  describe "::write_with_prompt" do
    it "returns :created and writes when file missing", :check_output do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "a.txt")
        out = capture(:stdout) { expect(described_class.write_with_prompt(path, "hi")).to eq(:created) }
        expect(File.read(path)).to eq("hi")
        expect(out).to include("Created")
      end
    end

    it "is idempotent and returns :skipped when content unchanged" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "a.txt")
        File.write(path, "same")
        expect(described_class.write_with_prompt(path, "same")).to eq(:skipped)
      end
    end

    it "replaces file when chosen", :check_output do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "a.txt")
        File.write(path, "old")
        allow(described_class).to receive(:ask_overwrite).and_return(:replace_file)
        out = capture(:stdout) { expect(described_class.write_with_prompt(path, "new")).to eq(:updated) }
        expect(File.read(path)).to eq("new")
        expect(out).to include("Updated")
      end
    end

    it "appends to file when chosen", :check_output do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "a.txt")
        File.write(path, "old")
        allow(described_class).to receive(:ask_overwrite).and_return(:append)
        out = capture(:stdout) { expect(described_class.write_with_prompt(path, "+++")).to eq(:updated) }
        expect(File.read(path)).to eq("old+++")
        expect(out).to include("Appended")
      end
    end

    it "skips when chosen", :check_output do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "a.txt")
        File.write(path, "old")
        allow(described_class).to receive(:ask_overwrite).and_return(:skip)
        out = capture(:stdout) { expect(described_class.write_with_prompt(path, "new")).to eq(:skipped) }
        expect(File.read(path)).to eq("old")
        expect(out).to include("Skipped")
      end
    end

    it "aborts when chosen" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "a.txt")
        File.write(path, "old")
        allow(described_class).to receive(:ask_overwrite).and_return(:abort)
        expect { described_class.write_with_prompt(path, "new") }.to raise_error(SystemExit)
      end
    end
  end

  describe "::ask_continue_on_invalid", :check_output do
    it "honors ENV override values" do
      stub_env("FF_BADDATA_CHOICE" => "continue")
      expect(described_class.ask_continue_on_invalid(%w[a], "lib")).to eq(:continue)
      stub_env("FF_BADDATA_CHOICE" => "abort")
      expect(described_class.ask_continue_on_invalid(%w[a], "lib")).to eq(:abort)
    end

    it "prompts user when no ENV override and accepts entries" do
      allow($stdin).to receive(:gets).and_return("c\n")
      expect(described_class.ask_continue_on_invalid(%w[a b], "lib")).to eq(:continue)
      allow($stdin).to receive(:gets).and_return("a\n")
      expect(described_class.ask_continue_on_invalid(%w[x], "lib")).to eq(:abort)
    end
  end
end
# rubocop:enable RSpec/MultipleExpectations
