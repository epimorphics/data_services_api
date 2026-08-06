# frozen_string_literal: true

module DataServicesApi
  # Encapsulates a single value coming back from the API
  class Value < Hash
    def initialize(base = {}, adds = {})
      super()

      merge!(base)
        .merge!(adds)
      freeze
    end

    def value
      self['@value']
    end

    def type # steep:ignore MethodBodyTypeMismatch
      self['@type']
    end

    def uri # steep:ignore MethodBodyTypeMismatch
      self['@id']
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
      with_typed_value(format('%04<year_digits>d-%02<month_digits>d',
                              year_digits: year.to_i,
                              month_digits: month.to_i),
                       'http://www.w3.org/2001/XMLSchema#gYearMonth')
    end

    def self.year_month(year, month)
      Value.new.with_year_month(year, month)
    end
  end
end
