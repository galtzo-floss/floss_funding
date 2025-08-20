# frozen_string_literal: true

require "yaml"
require "fileutils"

require "floss_funding/rakelib/gem_spec_reader"
require "floss_funding/validators"
require "floss_funding/rake_helpers"

namespace :floss_funding do
  include FlossFunding::RakeHelpers

  desc "Install or update FlossFunding support files (.floss_funding.yml, .gitignore sentinels). Idempotent per file with prompts (diff/replace file/append/skip/abort)."
  task :install, [:force] do |_, args|
    args ||= {}
    force = !!(args[:force] && args[:force].to_s == "true") || ENV["FORCE"] == "true"

    # Determine project root, fall back to Dir.pwd
    project_root = FlossFunding::Config.find_project_root || Dir.pwd

    # 1) Prepare .floss_funding.yml content
    dest_path = File.join(project_root, ".floss_funding.yml")

    # Load defaults from the gem's config/default.yml
    defaults = FlossFunding::ConfigLoader.default_configuration.dup

    # Read gemspec-derived data
    gemspec_data = FlossFunding::Rakelib::GemSpecReader.read(project_root)

    # Merge: gemspec values take precedence over defaults when present
    merged = defaults.merge(
      "library_name" => gemspec_data[:library_name],
      "homepage" => gemspec_data[:homepage],
      "authors" => gemspec_data[:authors],
      "email" => gemspec_data[:email],
      "funding_uri" => gemspec_data[:funding_uri],
    ).compact

    # Validate and sanitize before writing
    sanitized, invalids = FlossFunding::Validators.sanitize_config(merged)
    lib_for_log = sanitized["library_name"] || gemspec_data[:library_name] || "(unknown)"
    unless invalids.empty?
      begin
        FlossFunding.debug_log { "[install][invalid] lib=#{lib_for_log.inspect} attrs=#{invalids.join(", ")}" }
      rescue StandardError
      end
      choice = ask_continue_on_invalid(invalids, lib_for_log)
      if choice == :abort
        abort("floss_funding: Aborted due to invalid values in suggested config")
      end
    end

    # Ensure required keys are present (may still be nil if not in gemspec)
    missing = FlossFunding::REQUIRED_YAML_KEYS.reject { |k| sanitized.key?(k) && sanitized[k] && sanitized[k].to_s.strip != "" }
    unless missing.empty?
      warn "floss_funding: Warning - missing suggested values for: #{missing.join(", ")}. You can edit #{dest_path} to fill them in."
    end

    if File.exist?(dest_path) && !force
      # Existing file: handle via prompt if content differs
      write_with_prompt(dest_path, sanitized.to_yaml)
    else
      # Forced overwrite or create
      FileUtils.mkdir_p(project_root)
      File.write(dest_path, sanitized.to_yaml)
      puts "floss_funding: #{File.exist?(dest_path) ? "Overwrote" : "Installed"} #{dest_path}"
    end

    # 2) Ensure .gitignore contains sentinels ignore line (independent from config)
    gitignore_path = File.join(project_root, ".gitignore")
    ensure_gitignore_sentinels(gitignore_path)
  end
end
