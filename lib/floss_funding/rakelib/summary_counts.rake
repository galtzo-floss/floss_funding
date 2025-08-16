# frozen_string_literal: true

# Development helper task delegating to the standalone script.
# Keeps backward compatibility for `rake floss_funding:summary_counts`.

namespace :floss_funding do
  desc "Run common dev commands and count 'FLOSS Funding Summary' occurrences in their outputs"
  task :summary_counts do
    script = File.expand_path(File.join(__dir__, "..", "..", "..", "bin", "summary_counts"))
    # Prefer repo bin/ if available; fallback to invoking via path
    if File.exist?(script)
      system(script) || abort("summary_counts script failed")
    else
      system("bin/summary_counts") || abort("bin/summary_counts failed or not found")
    end
  end
end
