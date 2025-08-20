            # frozen_string_literal: true
            module VendoredGem
              module Core; end
            end
            require "floss_funding"
            VendoredGem::Core.send(:include, FlossFunding::Poke.new(__FILE__, namespace: "VendoredGem"))
