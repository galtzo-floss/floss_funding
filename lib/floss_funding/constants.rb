# frozen_string_literal: true

module FlossFunding
  # Constants that act as runtime control switches and may need to be
  # reloaded in tests without reloading the entire library.
  module Constants
    # Default ENV prefix used when constructing activation ENV variable names.
    # Can be globally overridden for the entire process by setting
    # ENV['FLOSS_CFG_FUND_ENV_PREFIX'] to a String (including an empty String
    # to indicate no prefix at all).
    # :nocov:
    # DEFAULT_PREFIX can be overridden via ENV. Exercising the "then" branch
    # would require reloading this file with a modified ENV in-process.
    DEFAULT_PREFIX = if ENV.key?("FLOSS_CFG_FUND_ENV_PREFIX")
      ENV["FLOSS_CFG_FUND_ENV_PREFIX"]
    else
      "FLOSS_CFG_FUNDING_"
    end
    # :nocov:

    # Global silence switch controlled by ENV.
    # When ENV['FLOSS_CFG_FUND_SILENT'] case-insensitively equals
    # "CATHEDRAL_OR_BAZAAR", SILENT is true; otherwise false.
    SILENT = begin
      v = ENV["FLOSS_CFG_FUND_SILENT"]
      v.to_s.casecmp("CATHEDRAL_OR_BAZAAR") == 0
    rescue StandardError
      false
    end
  end
end
