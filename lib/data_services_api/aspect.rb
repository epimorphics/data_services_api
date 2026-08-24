# frozen_string_literal: true

module DataServicesApi
  # Encapsulates a DSAPI Aspect
  # This corresponds to one of the measures of the underlying data cube, which
  # becomes an _aspect_ of the object description that the DSApi query encapsulates.
  # See https://github.com/epimorphics/data-API/wiki/Data-Query-Syntax
  class Aspect
    attr_reader :service

    def initialize(json, service)
      @json = json
      @service = service
    end

    def id # steep:ignore MethodBodyTypeMismatch
      @json['@id']
    end

    alias uri id

    def method_missing(name)
      respond_to_missing?(name) ? @json[name.to_s] : super
    end

    def respond_to_missing?(name, _args = nil)
      @json.key?(name.to_s)
    end

    def optional?
      isOptional
    end

    def multi_valued?
      isMultiValued
    end

    def range_type
      rangeType
    end
  end
end
