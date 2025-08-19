# frozen_string_literal: true

require "yaml"
require "fileutils"

require "floss_funding/rakelib/gem_spec_reader"
require "floss_funding/validators"

namespace :floss_funding do
  desc "Install or update FlossFunding support files (.floss_funding.yml, .gitignore sentinels). Idempotent per file with prompts (diff/replace file/append/skip/abort)."
  task :install, [:force] do |_, args|
    # Simple interactive prompt modeled after common installers. Can be overridden
    # by setting FF_INSTALL_CHOICE to one of: replace_file, append, skip, abort, diff
    # Backwards-compat: also accepts "overwrite" but maps it to :replace_file.
    def ask_overwrite(path, default_choice = nil, prompt: nil)
      env_choice = ENV["FF_INSTALL_CHOICE"].to_s.downcase.strip
      case env_choice
      when "replace_file", "rf", "replace file", "overwrite", "o" then return :replace_file
      when "append", "p" then return :append
      when "skip", "s" then return :skip
      when "abort", "a" then return :abort
      when "diff", "d" then return :diff
      end

      loop do
        prompt ||= "#{path} exists. [d]iff, [r]eplace file, ap[p]end, [s]kip, [a]bort?"
        prompt += " (default: #{default_choice.to_s[0]})" if default_choice
        print(prompt + " ")
        $stdout.flush
        ans_line = $stdin.gets
        ans = ans_line ? ans_line.strip.downcase : nil
        if (ans.nil? || ans == "") && default_choice
          return default_choice
        end
        case ans
        when "d" then return :diff
        when "r" then return :replace_file
        when "o" then return :replace_file # legacy alias
        when "p" then return :append
        when "s" then return :skip
        when "a" then return :abort
        end
        puts "Please choose d/r/p/s/a."
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
          when :replace_file
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

    # Ensure a .gitignore contains the Sentinels section and required lock line
    # Behavior:
    # - If '# Sentinels' not found, prompt; on append, add a blank line, then the
    #   section header and the lock line.
    # - If found and the section already contains the lock line, auto-skip silently.
    # - If found and missing the lock line, display the section chunk, prompt with
    #   append as the default, and only add the lock line within that section.
    # :nocov:
    def ensure_gitignore_sentinels(path, header = "# Sentinels", lock_line = ".floss_funding.*.lock")
      header = header.strip
      lock_line = lock_line.strip

      if !File.exist?(path)
        # Create file with header and lock line
        content = "#{header}\n#{lock_line}\n"
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, content)
        puts "floss_funding: Created #{path} with Sentinels section"
        return :created
      end

      current = File.read(path)
      lines = current.split("\n")
      sentinel_idx = lines.index { |l| l.strip == header }

      if sentinel_idx.nil?
        # No header present: propose to add a new section with a leading blank line
        to_append = String.new
        to_append << "\n" unless current.end_with?("\n")
        to_append << "\n#{header}\n#{lock_line}\n"
        # Show the resulting diff before prompting
        show_diff(current, current + to_append)
        loop do
          choice = ask_overwrite(path)
          case choice
          when :diff
            show_diff(current, current + to_append)
            next
          when :replace_file
            File.write(path, current + to_append)
            puts "floss_funding: Updated #{path} (added Sentinels section)"
            return :updated
          when :append
            File.open(path, "a") { |f| f.write(to_append) }
            puts "floss_funding: Appended Sentinels section to #{path}"
            return :updated
          when :skip
            puts "floss_funding: Skipped updating #{path}"
            return :skipped
          when :abort
            abort("floss_funding: Aborted by user while processing #{path}")
          end
        end
      else
        # Find end of section: next line starting with '#' after sentinel_idx
        next_comment_idx = nil
        ((sentinel_idx + 1)...lines.length).each do |i|
          if lines[i].to_s.strip.start_with?("#")
            next_comment_idx = i
            break
          end
        end
        section_end = next_comment_idx || lines.length
        section_lines = lines[sentinel_idx...section_end]

        # If lock line already present in this section, auto-skip
        if section_lines.any? { |l| l.strip == lock_line }
          # silently skip (no prompt)
          return :skipped
        end

        # Prepare new content by inserting lock line at the end of the section
        new_lines = lines.dup
        insert_at = section_end
        new_lines.insert(insert_at, lock_line)
        new_content = new_lines.join("\n")
        new_content += "\n" unless new_content.end_with?("\n")

        # Show the resulting diff for the proposed change (append) before prompting
        show_diff(current, new_content)

        loop do
          # Custom prompt for this context (no "replace chunk"): default append
          prompt = "#{path} exists. [d]iff, ap[p]end, [s]kip, [a]bort? (default: p)"
          print(prompt + " ")
          $stdout.flush
          ans_line = $stdin.gets
          ans = ans_line ? ans_line.strip.downcase : ""
          ans = "p" if ans.nil? || ans == ""
          case ans
          when "d"
            show_diff(current, new_content)
            next
          when "p"
            File.write(path, new_content)
            puts "floss_funding: Added #{lock_line} to Sentinels section in #{path}"
            return :updated
          when "s"
            puts "floss_funding: Skipped updating #{path}"
            return :skipped
          when "a"
            abort("floss_funding: Aborted by user while processing #{path}")
          else
            puts "Please choose d/p/s/a."
          end
        end
      end
    end
    # :nocov:

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
