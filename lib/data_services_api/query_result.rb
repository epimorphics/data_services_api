# frozen_string_literal: true

module DataServicesApi
  # The rows returned by Dataset#query, with the API's `meta` alongside them.
  # It's an Array, so callers that only want the rows needn't change, but
  # methods that build a new array, such as `map` or `select`, return a plain
  # Array without `meta`, so read `meta` from the result itself.
  class QueryResult < Array
    # The API's `meta` for the response, or an empty Hash if it sent none.
    # For a list, `meta['limit']` is the limit the API actually applied: the
    # endpoint's hard limit overrides a larger `_limit`, so a result with that
    # many rows may have been capped.
    attr_reader :meta

    def initialize(rows = [], meta = nil)
      super(rows)
      @meta = meta || {}
    end
  end
end
