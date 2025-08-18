            # frozen_string_literal: true
            $LOAD_PATH.unshift(File.expand_path("../../lib", __dir__))
            require "poked_gem_with_dummy_spec_app"
            puts "dummy-ok"
