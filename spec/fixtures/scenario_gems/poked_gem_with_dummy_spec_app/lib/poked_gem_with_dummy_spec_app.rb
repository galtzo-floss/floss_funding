            # frozen_string_literal: true
            module PokedGemWithDummySpecApp
              module Core; end
            end
            require "floss_funding"
            PokedGemWithDummySpecApp::Core.send(:include, FlossFunding::Poke.new(__FILE__, namespace: "PokedGemWithDummySpecApp"))
