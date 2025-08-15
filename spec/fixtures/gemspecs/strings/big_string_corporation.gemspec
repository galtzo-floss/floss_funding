# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = "big_corporation"
  spec.version = "1.0.0"
  spec.authors = ["Peter H. Boling"]
  spec.email = ["floss@galtzo.com"]

  spec.summary = "Do Big Corporate Things"
  spec.description = "Eat All The Big Corporate Lunches"
  spec.homepage = "https://github.com/galtzo-floss/#{spec.name}"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 1.9.2"

  spec.metadata["homepage_uri"] = "https://#{spec.name.tr("_", "-")}.galtzo.com/"
  spec.metadata["source_code_uri"] = "#{spec.homepage}/tree/v#{spec.version}"
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/v#{spec.version}/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"
  spec.metadata["documentation_uri"] = "https://www.rubydoc.info/gems/#{spec.name}/#{spec.version}"
  spec.metadata["funding_uri"] = "https://github.com/sponsors/pboling"
  spec.metadata["wiki_uri"] = "#{spec.homepage}/wiki"
  spec.metadata["news_uri"] = "https://www.railsbling.com/tags/#{spec.name}"
  spec.metadata["discord_uri"] = "https://discord.gg/3qme4XHNKN"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files are part of the released package.
  spec.files = Dir[
    # Splats (alphabetical)
    "lib/**/*.rb",
  ]
  spec.require_paths = ["lib"]
  spec.bindir = "exe"
  # files listed are relative paths from bindir above.
  spec.executables = []

  spec.add_dependency("month-serializer", "~> 1.0", "1.0.1")                                # ruby >= 1.9.2
  # Exclude broken rainbow releases: https://github.com/ku1ik/rainbow/blob/master/Changelog.md
  spec.add_dependency("psych", ">= 2.2.4") # ruby > 1.9.2
  spec.add_dependency("rainbow", ">= 1.99.2", "!= 2.2.0", "!= 2.2.1", "!= 3.1.0", "< 4.0")  # ruby > 0
  spec.add_dependency("ruby-progressbar", "~> 1.13")                                        # ruby > 0
  spec.add_dependency("terminal-table", "~> 4.0")

  # Release Tasks
  spec.add_development_dependency("stone_checksums", "~> 1.0")            # ruby >= 2.2.0

  ### Testing
  spec.add_development_dependency("appraisal2", "~> 3.0")                 # ruby >= 1.8.7
  spec.add_development_dependency("rspec", "~> 3.13")                     # ruby > 0
  spec.add_development_dependency("rspec-block_is_expected", "~> 1.0")    # ruby >= 1.8.7
  spec.add_development_dependency("rspec_junit_formatter", "~> 0.6")      # ruby >= 2.3.0, for GitLab Test Result Parsing
  spec.add_development_dependency("rspec-stubbed_env", "~> 1.0")          # ruby >= 2.3.0 (helper for stubbing ENV in specs)
  spec.add_development_dependency("silent_stream", "~> 1.0", ">= 1.0.11") # ruby >= 2.3.0, for output capture
  spec.add_development_dependency("timecop", "~> 0.9", ">= 0.9.10")       # ruby >= 1.9.2

  # Development tasks
  spec.add_development_dependency("rake", "~> 13.0")                      # ruby >= 2.2
end
