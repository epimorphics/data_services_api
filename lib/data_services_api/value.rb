# frozen_string_literal: true

module DataServicesApi
  # Encapsulates a single JSON-LD value node coming back from, or destined
  # for, the API: a scalar with an optional @type, or a URI reference (@id).
  #
  # This is a Hash so that #to_json (and anything else relying on Hash's
  # native JSON serialization, e.g. QueryGenerator building request terms)
  # produces the correct JSON-LD shape for free, since the storage keys
  # (@value/@type/@id) are the wire format. Internal storage is always
  # String-keyed, and [] is overridden to normalize lookups, so callers can
  # use either String or Symbol keys without silently missing.
  class Value < Hash
    def initialize(base = {}, adds = {})
      super()

      merge!(base.transform_keys(&:to_s))
        .merge!(adds.transform_keys(&:to_s))
      freeze
    end

    def [](key)
      super(key.to_s)
    end

    def value
      self['@value']
    end

    def type
      self['@type']
    end

    def uri
      self['@id']
    end

    # Parse a raw JSON-LD value node, however it was decoded (String- or
    # Symbol-keyed hash — from JSON.parse, from a test fixture written with
    # symbol literals, doesn't matter).
    def self.from_json_ld(node)
      new(node)
    end

    def with_uri(uri)
      Value.new(self, { '@id' => uri })
    end

    def self.uri(uri)
      Value.new.with_uri(uri)
    end

    def with_typed_value(value, type)
      Value.new(self, { '@value' => value, '@type' => type })
    end

    def with_year_month(year, month)
      with_typed_value(
        format('%04<year_digits>d-%02<month_digits>d', year_digits: year.to_i,
                                                       month_digits: month.to_i),
        'http://www.w3.org/2001/XMLSchema#gYearMonth'
      )
    end

    def self.year_month(year, month)
      Value.new.with_year_month(year, month)
    end
  end
end
