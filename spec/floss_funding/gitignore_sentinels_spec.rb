# frozen_string_literal: true

require "rake"

RSpec.describe "floss_funding:install gitignore Sentinels handling" do
  include_context "with stubbed env"

  let(:rake_app) { Rake::Application.new }
  let(:rakefile_path) { File.expand_path("../../lib/floss_funding/rakelib/floss_funding.rake", __dir__) }

  def load_tasks!(app)
    Rake.application = app
    load rakefile_path
  end

  def write_minimal_project(dir)
    File.write(File.join(dir, "Gemfile"), "source 'https://rubygems.org'\n")
    content = <<GEMSPEC
Gem::Specification.new do |s|
  s.name = "tmpgem"
  s.version = "0.1.0"
  s.summary = "tmp"
  s.authors = ["Tmp"]
  s.email = "tmp@example.com"
  s.homepage = "https://example.invalid"
  s.metadata = {"funding_uri"=>"https://fund.invalid"}
end
GEMSPEC
    File.write(File.join(dir, "tmpgem.gemspec"), content)
  end

  before do
    load_tasks!(rake_app)
  end

  it "adds a new Sentinels section with a leading blank line when not present and append chosen" do
    Dir.mktmpdir do |dir|
      write_minimal_project(dir)
      allow(FlossFunding::Config).to receive(:find_project_root).and_return(dir)

      gi = File.join(dir, ".gitignore")
      File.write(gi, "existing\n")

      stub_env("FF_INSTALL_CHOICE" => "append")

      rake_app["floss_funding:install"].invoke

      content = File.read(gi)
      expect(content).to include("existing\n\n# Sentinels\n.floss_funding.*.lock\n")
    end
  end

  it "auto-skips without prompting when section contains the lock line already" do
    Dir.mktmpdir do |dir|
      write_minimal_project(dir)
      allow(FlossFunding::Config).to receive(:find_project_root).and_return(dir)

      gi = File.join(dir, ".gitignore")
      initial = [
        "# Sentinels",
        ".floss_funding.*.lock",
        "# Next",
      ].join("\n") + "\n"
      File.write(gi, initial)

      # Ensure no prompt is attempted
      allow($stdin).to receive(:gets).and_raise("no prompt expected")

      expect {
        rake_app["floss_funding:install"].invoke
      }.not_to raise_error

      expect(File.read(gi)).to eq(initial)
    end
  end

  it "shows a diff of the proposed change and defaults to append; only adds the lock line within the section", :check_output do
    Dir.mktmpdir do |dir|
      write_minimal_project(dir)
      allow(FlossFunding::Config).to receive(:find_project_root).and_return(dir)

      gi = File.join(dir, ".gitignore")
      initial = [
        "foo",
        "# Sentinels",
        "other",
        "# OS Detritus",
        "bar",
      ].join("\n") + "\n"
      File.write(gi, initial)

      # No explicit choice; press Enter to accept default (append)
      allow($stdin).to receive(:gets).and_return("")

      output = capture(:stdout) do
        rake_app["floss_funding:install"].invoke
      end

      # Shows a diff preview before prompting
      expect(output).to include("--- current")
      expect(output).to include("+++ new")
      expect(output).to include("+ .floss_funding.*.lock")

      expected = [
        "foo",
        "# Sentinels",
        "other",
        ".floss_funding.*.lock",
        "# OS Detritus",
        "bar",
      ].join("\n") + "\n"
      expect(File.read(gi)).to eq(expected)
    end
  end
end
