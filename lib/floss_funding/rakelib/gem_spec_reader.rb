module FlossFunding
  module Rakelib
    module GemSpecReader
      # Reads gemspec data from the first *.gemspec in library_root using
      # RubyGems API, and extracts fields of interest.
      # @param library_root [String]
      # @return [Hash] keys: :name, :homepage, :authors, :funding_uri
      def read(library_root)
        gemspec_path = Dir.glob(File.join(library_root, "*.gemspec")).first
        return {} unless gemspec_path
        begin
          spec = Gem::Specification.load(gemspec_path)
          return {} unless spec
          puts "Loaded gemspec: #{spec}" if DEBUG
          metadata = spec.metadata || {}
          puts "metadata: #{metadata.inspect}" if DEBUG
          extracted = {
            :library_name => spec.name,
            :homepage => spec.homepage,
            :authors => spec.authors,
            :email => spec.email,
          }
          # Gemspec metadata is keyed exactly the gem author keyed it.
          # Thus, support both symbol and string keys.
          extracted[:funding_uri] = metadata["funding_uri"]
          extracted[:funding_uri] ||= metadata[:funding_uri]
          puts "extracted: #{extracted.inspect}" if DEBUG
          extracted
        rescue StandardError => error
          warn("[floss_funding] Error reading gemspec in #{library_root}:\n  #{error.class}:\n  #{error.message}")
          {}
        end
      end
      module_function :read
    end
  end
end
