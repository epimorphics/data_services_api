# frozen_string_literal: true

# :nodoc:
module DataServicesApi
  # Adapter-pattern to present a response from SapiNT in the same JSON structure
  # that the old DsAPI was using
  class DSAPIResponseConverter
    def initialize(sapint_response, dataset_name, json_mode_compact = false)
      @sapint_response = sapint_response
      @dataset_name = dataset_name
      @json_mode_compact = json_mode_compact
    end

    # Converts SAPINT returned JSON format to DSAPI returned JSON format
    def to_dsapi_response
      @sapint_response['items'].map do |value|
        to_dsapi_item(value)
      end
    end

    private

    def to_dsapi_item(sapint_item)
      sapint_item.reduce({}) do |result, (key, value)|
        result.merge(to_dsapi_json(key, value))
      end
    end

    # Return different response formats based on the set JSON mode
    def to_dsapi_json(sapint_key, sapint_value)
      return json_mode_compact(sapint_key, sapint_value) if @json_mode_compact

      json_mode_complete(sapint_key, sapint_value)
    end

    def json_mode_compact(sapint_key, sapint_value)
      return { sapint_key => sapint_value } if sapint_key == '@id'
      return { "#{@dataset_name}:#{sapint_key}" => sapint_value } unless sapint_value.is_a?(Hash)

      sapint_value.transform_keys do |key|
        "#{@dataset_name}:#{sapint_key}#{key.capitalize unless key == '@id'}"
      end
    end

    def json_mode_complete(sapint_key, sapint_value)
      case sapint_key
      when '@id'
        return { sapint_key => sapint_value }
      when 'refMonth'
        return { "#{@dataset_name}:#{sapint_key}" => { '@value' => sapint_value } }
      when 'refPeriodStart'
        return { "#{@dataset_name}:#{sapint_key}" => [{ '@value' => sapint_value }] }
      end
      return { "#{@dataset_name}:#{sapint_key}" => [sapint_value] } unless sapint_value.is_a?(Hash)

      { "#{@dataset_name}:#{sapint_key}" => sapint_value }
    end
  end
end
