# frozen_string_literal: true

module DataServicesApi
  # An immutable JSON-LD value node: a scalar with an optional @type,
  # or a URI reference (@id). Not Hash-like — read it through the named
  # accessors below, not `[]`.
  class Value
    attr_reader :value, :type, :uri

    def initialize(value: nil, type: nil, uri: nil)
      @value = value
      @type = type
      @uri = uri
      freeze
    end

    # Parse a raw JSON-LD value node, however it was decoded
    # (String- or Symbol-keyed hash — from JSON.parse, from a test
    # fixture written with symbol literals, doesn't matter).
    def self.from_json_ld(node)
      node = node.transform_keys(&:to_s)
      new(value: node['@value'], type: node['@type'], uri: node['@id'])
    end

    def self.uri(uri)
      new(uri: uri)
    end

    def with_uri(uri)
      self.class.new(value: value, type: type, uri: uri)
    end

    def with_typed_value(value, type)
      self.class.new(value: value, type: type, uri: uri)
    end

    def with_year_month(year, month)
      with_typed_value(
        format('%04<year_digits>d-%02<month_digits>d', year_digits: year.to_i,
                                                       month_digits: month.to_i),
        'http://www.w3.org/2001/XMLSchema#gYearMonth'
      )
    end

    def self.year_month(year, month)
      new.with_year_month(year, month)
    end

    def ==(other)
      other.is_a?(Value) && value == other.value && type == other.type && uri == other.uri
    end
  end
end
