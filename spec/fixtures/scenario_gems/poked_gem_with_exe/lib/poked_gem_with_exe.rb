            # frozen_string_literal: true
            module PokedGemWithExe
              module Core; end
            end
            require "floss_funding"
            PokedGemWithExe::Core.send(:include, FlossFunding::Poke.new(__FILE__, namespace: "PokedGemWithExe"))
