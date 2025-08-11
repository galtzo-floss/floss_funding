# frozen_string_literal: true

module FlossFunding
  # Constants that act as runtime control switches and may need to be
  # reloaded in tests without reloading the entire library.
  module Constants
    # Default ENV prefix used when constructing activation ENV variable names.
    # Can be globally overridden for the entire process by setting
    # ENV['FLOSS_FUNDING_ENV_PREFIX'] to a String (including an empty String
    # to indicate no prefix at all).
    # :nocov:
    # DEFAULT_PREFIX can be overridden via ENV. Exercising the "then" branch
    # would require reloading this file with a modified ENV in-process.
    DEFAULT_PREFIX = if ENV.key?("FLOSS_FUNDING_ENV_PREFIX")
      ENV["FLOSS_FUNDING_ENV_PREFIX"]
    else
      "FLOSS_FUNDING_"
    end
    # :nocov:

    # Global silence switch controlled by ENV.
    # When ENV['FLOSS_FUNDING_SILENT'] case-insensitively equals
    # "CATHEDRAL_OR_BAZAAR", SILENT is true; otherwise false.
    SILENT = ENV.fetch("FLOSS_FUNDING_SILENT", "false").casecmp("CATHEDRAL_OR_BAZAAR") == 0
  end
end
