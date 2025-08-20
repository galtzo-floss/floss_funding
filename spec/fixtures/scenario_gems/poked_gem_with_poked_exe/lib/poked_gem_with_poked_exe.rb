            # frozen_string_literal: true
            module PokedGemWithPokedExe
              module Core; end
            end
            require "floss_funding"
            PokedGemWithPokedExe::Core.send(:include, FlossFunding::Poke.new(__FILE__, namespace: "PokedGemWithPokedExe"))
