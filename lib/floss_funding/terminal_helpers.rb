# frozen_string_literal: true

module FlossFunding
  # Helpers for interacting with terminal characteristics
  module Terminal
    module_function

    # Determine current terminal columns, checking tput each time for up-to-date size.
    # Returns an Integer or nil when unknown.
    def columns
      cols = nil
      # Prefer tput, over TTY::Screen.width (from the tty-screen gem), for cross-platform compatibility
      begin
        out = %x(tput cols 2>/dev/null).to_s.strip
        cols = Integer(out) unless out.empty?
      rescue StandardError
        # ignore
      end

      # Fallback to COLUMNS env
      if cols.nil? || cols <= 0
        begin
          env_cols = ENV["COLUMNS"]
          cols = Integer(env_cols) if env_cols && !env_cols.to_s.empty?
        rescue StandardError
          # ignore
        end
      end

      # Fallback to IO.console only if it looks like a TTY context
      if (cols.nil? || cols <= 0) && $stdout.tty?
        begin
          require "io/console"
          _, c = IO.console.winsize
          cols = c if c && c > 0
        rescue StandardError
          # ignore
        end
      end

      (cols.is_a?(Integer) && cols > 0) ? cols : nil
    end

    # Apply detected width to a Terminal::Table instance when possible.
    def apply_width!(table)
      cols = columns
      table.style = {:width => cols} if cols && cols > 0
      table
    rescue StandardError
      table
    end
  end
end
