          # frozen_string_literal: true

          # Main library module for gem1_with_vendored
          module Gem1WithVendored
            # In real usage this gem would "vendor" another gem inside its tree.
            # For fixture purposes, require the vendored lib.
            begin
              require "vendor_gem"
            rescue LoadError
              # Try relative require for test environments
              begin
                require_relative "../../vendor/vendored_lib/lib/vendor_gem"
              rescue LoadError
                # ignore if not present in load path yet
              end
            end

            # Optionally, this gem could also include FlossFunding directly, but Wedge will inject when run.
            # include FlossFunding::Poke.new(__FILE__)
          end
