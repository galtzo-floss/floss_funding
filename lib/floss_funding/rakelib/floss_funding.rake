# frozen_string_literal: true

require "yaml"
require "fileutils"

namespace :floss_funding do
  desc "Install a default .floss_funding.yml by merging gemspec data with defaults"
  task :install, [:force] do |_, args|
    args ||= {}
    force = !!(args[:force] && args[:force].to_s == "true") || ENV["FORCE"] == "true"

    # Determine project root, fall back to Dir.pwd
    project_root = FlossFunding::Config.find_project_root || Dir.pwd
    dest_path = File.join(project_root, ".floss_funding.yml")

    if File.exist?(dest_path) && !force
      puts "floss_funding: .floss_funding.yml already exists at #{dest_path}. Use FORCE=true or rake floss_funding:install[true] to overwrite."
      next
    end

    # Load defaults from the gem's config/default.yml
    defaults = FlossFunding::ConfigLoader.default_configuration.dup

    # Read gemspec-derived data (private API; explicitly using send)
    gemspec_data = FlossFunding::Config.send(:read_gemspec_data, project_root)

    # Merge: gemspec values take precedence over defaults when present
    merged = defaults.merge(
      "library_name" => gemspec_data[:library_name],
      "homepage" => gemspec_data[:homepage],
      "authors" => gemspec_data[:authors],
      "email" => gemspec_data[:email],
      "funding_uri" => gemspec_data[:funding_uri],
    ).compact

    # Ensure required keys are present (may still be nil if not in gemspec)
    missing = FlossFunding::REQUIRED_YAML_KEYS.reject { |k| merged.key?(k) && merged[k] && merged[k].to_s.strip != "" }
    unless missing.empty?
      warn "floss_funding: Warning - missing suggested values for: #{missing.join(", ")}. You can edit #{dest_path} to fill them in."
    end

    FileUtils.mkdir_p(project_root)
    File.write(dest_path, merged.to_yaml)
    puts "floss_funding: Installed #{dest_path}"
  end
end
