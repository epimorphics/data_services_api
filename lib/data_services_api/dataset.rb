# frozen_string_literal: true

module DataServicesApi
  # Encapsulates a single dataset from the data services API
  class Dataset
    attr_reader :service

    def initialize(json, service)
      @json = json
      @service = service
    end

    def id # steep:ignore MethodBodyTypeMismatch
      @json['@id']
    end

    def method_missing(attribute)
      respond_to_missing?(attribute, nil) ? @json[attribute.to_s] : super
    end

    def respond_to_missing?(attribute, _args = nil)
      @json.key?(attribute.to_s)
    end

    def data_api
      @json['data-api']
    end

    def dataset # steep:ignore MethodBodyTypeMismatch
      @json['dataset']
    end

    def structure_api
      @json['structure-api']
    end

    def explain_api
      # TODO: There should be a HATEOS-style reference to this endpoint
      # https://github.com/epimorphics/ds-api-ruby/issues/1
      structure_api.gsub(/structure$/, 'explain')
    end

    def query(query)
      sapi_query_params = SapiNTConverter.new(query.to_json).to_sapint_query
      sapint_response = service.api_get_json(data_api, sapi_query_params)
      json_mode_compact = query.terms['@json_mode'] == 'compact'
      DSAPIResponseConverter.new(sapint_response, dataset, json_mode_compact).to_dsapi_response
    end

    def explain(query)
      sapi_query_params = SapiNTConverter.new(query.to_json).to_sapint_query
      explain_url = "#{data_api}/explain"
      service.api_get_json(explain_url, sapi_query_params)
    end
  end
end
