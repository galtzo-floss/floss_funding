# frozen_string_literal: true

# rubocop:disable RSpec/ContextWording, RSpec/MultipleExpectations

RSpec.describe FlossFunding do
  it "adds the rakelib directory without error" do
    require "rake"
    expect {
      require "floss_funding/tasks"
    }.not_to raise_error
  end

  context "with floss_funding:install task" do
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
      stub_env("FF_INSTALL_CHOICE" => "overwrite")
    end

    it "adds .gitignore sentinel even when .floss_funding.yml already exists" do
      Dir.mktmpdir do |dir|
        write_minimal_project(dir)
        allow(FlossFunding::Config).to receive(:find_project_root).and_return(dir)

        File.write(File.join(dir, ".floss_funding.yml"), {"library_name" => "tmpgem", "funding_uri" => "https://fund.invalid"}.to_yaml)

        rake_app["floss_funding:install"].invoke

        content = File.read(File.join(dir, ".gitignore"))
        expect(content).to include(".floss_funding.*.lock")
      end
    end

    it "is idempotent for .gitignore sentinel line and does not duplicate entries" do
      Dir.mktmpdir do |dir|
        write_minimal_project(dir)
        allow(FlossFunding::Config).to receive(:find_project_root).and_return(dir)

        task = rake_app["floss_funding:install"]
        task.invoke
        task.reenable
        task.invoke

        gi_path = File.join(dir, ".gitignore")
        content = File.read(gi_path)
        occurrences = content.scan(/^\.floss_funding\.\*\.lock$/).size
        expect(occurrences).to eq(1)
      end
    end
  end

  context "with append option behavior" do
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
      stub_env("FF_INSTALL_CHOICE" => "append")
    end

    it "appends to existing .floss_funding.yml instead of overwriting" do
      Dir.mktmpdir do |dir|
        write_minimal_project(dir)
        allow(FlossFunding::Config).to receive(:find_project_root).and_return(dir)

        dest = File.join(dir, ".floss_funding.yml")
        File.write(dest, "ORIGINAL\n")

        rake_app["floss_funding:install"].invoke

        content = File.read(dest)
        # single expectation: original preserved at start and yaml appended includes library_name key
        expect(content).to match(/\AORIGINAL\n.*library_name:/m)
      end
    end

    it "appends the .gitignore sentinel when append is chosen and file exists" do
      Dir.mktmpdir do |dir|
        write_minimal_project(dir)
        allow(FlossFunding::Config).to receive(:find_project_root).and_return(dir)

        gi = File.join(dir, ".gitignore")
        File.write(gi, "existing\n")

        rake_app["floss_funding:install"].invoke

        content = File.read(gi)
        # single expectation: preserves existing content and appends sentinel line
        expect(content).to match(/\Aexisting\n.*^\.floss_funding\.\*\.lock$/m)
      end
    end
  end

  context "additional branches for floss_funding:install" do
    include_context "with stubbed env"

    let(:rake_app) { Rake::Application.new }
    let(:rakefile_path) { File.expand_path("../../lib/floss_funding/rakelib/floss_funding.rake", __dir__) }

    def load_tasks!(app)
      Rake.application = app
      load rakefile_path
    end

    before do
      load_tasks!(rake_app)
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

    it "honors force=true and overwrites without prompt", :check_output do
      Dir.mktmpdir do |dir|
        write_minimal_project(dir)
        allow(FlossFunding::Config).to receive(:find_project_root).and_return(dir)
        dest = File.join(dir, ".floss_funding.yml")
        File.write(dest, "ORIGINAL\n")
        out = capture(:stdout) { rake_app["floss_funding:install"].invoke(true) }
        expect(out).to include("Overwrote")
        expect(File.read(dest)).to include("library_name:")
      end
    end

    it "warns about missing required keys before write when gemspec lacks them", :check_output do
      Dir.mktmpdir do |dir|
        # Project with gemspec missing metadata fields to force missing REQUIRED_YAML_KEYS
        File.write(File.join(dir, "Gemfile"), "source 'https://rubygems.org'\n")
        File.write(File.join(dir, "tmpgem.gemspec"), <<GEMSPEC)
Gem::Specification.new do |s|
  s.name = "tmpgem"
  s.version = "0.1.0"
  s.summary = "tmp"
end
GEMSPEC
        allow(FlossFunding::Config).to receive(:find_project_root).and_return(dir)
        # Force sanitize_config to return missing funding_uri so REQUIRED_YAML_KEYS fails
        allow(FlossFunding::Validators).to receive(:sanitize_config).and_return([{"library_name" => "tmpgem"}, []])
        err = capture(:stderr) { rake_app["floss_funding:install"].invoke }
        expect(err).to include("Warning - missing suggested values")
      end
    end

    it "aborts on invalids when FF_BADDATA_CHOICE=abort" do
      Dir.mktmpdir do |dir|
        write_minimal_project(dir)
        allow(FlossFunding::Config).to receive(:find_project_root).and_return(dir)
        # Force invalids to be present
        allow(FlossFunding::Validators).to receive(:sanitize_config).and_return([{}, {%w[a b] => nil}].then { |x| [x.first, %w[a b]] })
        stub_env("FF_BADDATA_CHOICE" => "abort")
        expect { rake_app["floss_funding:install"].invoke }.to raise_error(SystemExit)
      end
    end

    it "continues on invalids when FF_BADDATA_CHOICE=continue" do
      Dir.mktmpdir do |dir|
        write_minimal_project(dir)
        allow(FlossFunding::Config).to receive(:find_project_root).and_return(dir)
        allow(FlossFunding::Validators).to receive(:sanitize_config).and_return([{}, {%w[a b] => nil}].then { |x| [x.first, %w[a b]] })
        stub_env("FF_BADDATA_CHOICE" => "continue")
        expect { rake_app["floss_funding:install"].invoke }.not_to raise_error
      end
    end
  end
end
# rubocop:enable RSpec/ContextWording, RSpec/MultipleExpectations
