# frozen_string_literal: true

require "yaml"
require "fileutils"

require "floss_funding/rakelib/gem_spec_reader"
require "floss_funding/validators"

namespace :floss_funding do
  # Simple interactive prompt modeled after common installers. Can be overridden
  # by setting FF_INSTALL_CHOICE to one of: overwrite, append, skip, abort, diff
  def ask_overwrite(path)
    env_choice = ENV["FF_INSTALL_CHOICE"].to_s.downcase.strip
    case env_choice
    when "overwrite", "o" then return :overwrite
    when "append", "p" then return :append
    when "skip", "s" then return :skip
    when "abort", "a" then return :abort
    when "diff", "d" then return :diff
    end

    loop do
      print("#{path} exists. [d]iff, [o]verwrite, ap[p]end, [s]kip, [a]bort? ")
      $stdout.flush
      ans_line = $stdin.gets
      ans = ans_line ? ans_line.strip.downcase : nil
      case ans
      when "d" then return :diff
      when "o" then return :overwrite
      when "p" then return :append
      when "s" then return :skip
      when "a" then return :abort
      end
      puts "Please choose d/o/p/s/a."
    end
  end

  def show_diff(old_str, new_str)
    old_lines = (old_str || "").to_s.split("\n")
    new_lines = (new_str || "").to_s.split("\n")
    puts "--- current"
    puts "+++ new"
    max = [old_lines.size, new_lines.size].max
    max.times do |i|
      o = old_lines[i]
      n = new_lines[i]
      if o != n
        puts "- #{o}"
        puts "+ #{n}"
      end
    end
  end

  # Write a file with prompting when destination already exists and content differs.
  # Returns :created, :updated, :skipped
  def write_with_prompt(path, content)
    if File.exist?(path)
      current = File.read(path)
      return :skipped if current == content # idempotent
      loop do
        choice = ask_overwrite(path)
        case choice
        when :diff
          show_diff(current, content)
          next
        when :overwrite
          File.write(path, content)
          puts "floss_funding: Updated #{path}"
          return :updated
        when :append
          File.open(path, "a") { |f| f.write(content) }
          puts "floss_funding: Appended to #{path}"
          return :updated
        when :skip
          puts "floss_funding: Skipped #{path}"
          return :skipped
        when :abort
          abort("floss_funding: Aborted by user while processing #{path}")
        end
      end
    else
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, content)
      puts "floss_funding: Created #{path}"
      :created
    end
  end

  # Ensure a .gitignore contains a given line (idempotent). Uses the same
  # prompt logic when the file exists and needs to be updated.
  def ensure_gitignore_line(path, required_line)
    required_line = required_line.strip
    if File.exist?(path)
      current = File.read(path)
      return :skipped if current.split("\n").any? { |l| l.strip == required_line }
      new_content = (current.end_with?("\n") ? current : current + "\n") + required_line + "\n"
      # ask user whether to update
      loop do
        choice = ask_overwrite(path)
        case choice
        when :diff
          show_diff(current, new_content)
          next
        when :overwrite
          File.write(path, new_content)
          puts "floss_funding: Updated #{path} (added #{required_line})"
          return :updated
        when :append
          to_append = "#{current.end_with?("\n") ? "" : "\n"}#{required_line}\n"
          File.open(path, "a") { |f| f.write(to_append) }
          puts "floss_funding: Appended to #{path} (added #{required_line})"
          return :updated
        when :skip
          puts "floss_funding: Skipped updating #{path}"
          return :skipped
        when :abort
          abort("floss_funding: Aborted by user while processing #{path}")
        end
      end
    else
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, "#{required_line}\n")
      puts "floss_funding: Created #{path} with #{required_line}"
      :created
    end
  end

  def ask_continue_on_invalid(invalids, lib_name)
    env = ENV["FF_BADDATA_CHOICE"].to_s.downcase.strip
    if %w[continue abort].include?(env)
      return env.to_sym
    end
    puts "floss_funding: Detected invalid config values for #{lib_name.inspect}: #{invalids.size} attribute(s)."
    puts "See debug log for details (names only)."
    loop do
      print("Continue without invalid values? [c]ontinue / [a]bort: ")
      $stdout.flush
      ans = ($stdin.gets || "").strip.downcase
      case ans
      when "c", "continue"
        return :continue
      when "a", "abort"
        return :abort
      else
        puts "Please choose c/a."
      end
    end
  end

  desc "Install or update FlossFunding support files (.floss_funding.yml, .gitignore sentinels). Idempotent per file with prompts (diff/overwrite/skip/abort)."
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
    ensure_gitignore_line(gitignore_path, ".floss_funding.*.lock")
  end
end
