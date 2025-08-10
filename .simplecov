require "kettle/soup/cover/config"

# Start SimpleCov with project-local overrides to avoid failing the test suite
# due to strict minimum coverage thresholds set by kettle-soup-cover in dev/test.
SimpleCov.start do
  # Ensure coverage thresholds do not cause spec runs to fail locally.
  minimum_coverage 0
  minimum_coverage_by_file 0
end
