# frozen_string_literal: true

module DataServicesApi
  # Transformer to convert queries using the DsAPI query DSL
  # into an equivalent SapiNT query URL string
  class SapiNTConverter # rubocop:disable Metrics/ClassLength
    def initialize(dsapi_query)
      @dsapi_query = JSON.parse(dsapi_query)
    end

    # Converts a DSAPI query to SAPINT query
    def to_sapint_query
      @dsapi_query.reduce({}) do |res, (key, value)|
        json = sapint_query(key, value)
        res.merge(json || {})
      end
    end

    private

    def sapint_query(key, value) # rubocop:disable Metrics/MethodLength
      case key
      when '@sort'
        sort(value)
      when '@count'
        count(value)
      when '@limit'
        limit(value)
      when '@offset'
        offset(value)
      when '@and'
        and_list(value)
      end
    end

    def sort(values)
      values.to_h do |value|
        sort_prop = if value.key?('@up')
                      "+#{remove_prefix(value['@up'])}"
                    else
                      "-#{remove_prefix(value['@down'])}"
                    end
        ['_sort', sort_prop]
      end
    end

    def count(value)
      { '_count' => '@id' } if value
    end

    def limit(value)
      { '_limit' => value }
    end

    def offset(value)
      { '_offset' => value }
    end

    def and_list(list)
      list.reduce({}) do |result, value|
        result.merge(and_item(value)) do |key, oldval, newval|
          key == 'searchPath' ? oldval : [oldval].push(newval).flatten
        end
      end
    end

    def and_item(json_item)
      attribute = remove_prefix(json_item.first[0])
      attribute_json = json_item.first[1]
      relation = attribute_json.first[0]
      relation_json = attribute_json.first[1]
      relation(relation, attribute, relation_json)
    end

    def relation(relation, attribute, json) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/MethodLength
      case relation
      when '@eq'
        eq(attribute, json)
      when '@oneof'
        oneof(attribute, json)
      when '@ge'
        comparison('mineq', attribute, json)
      when '@gt'
        comparison('min', attribute, json)
      when '@le'
        comparison('maxeq', attribute, json)
      when '@lt'
        comparison('max', attribute, json)
      when '@search'
        search(attribute, json)
      end
    end

    def eq(attribute, value)
      return { attribute => value } unless value.is_a?(Hash)
      return { attribute => remove_prefix(value['@id']) } if value.key?('@id')

      { attribute => value['@value'] }
    end

    def oneof(attribute, values)
      values.reduce({}) do |result, value|
        result.merge(eq(attribute, value)) do |_key, oldval, newval|
          [oldval].push(newval).flatten
        end
      end
    end

    def comparison(prefix, attribute, value)
      return { "#{prefix}-#{attribute}" => value } unless value.is_a?(Hash)

      { "#{prefix}-#{attribute}" => value['@value'] }
    end

    def search(attribute, value)
      property = remove_prefix(value['@property'])
      search_text = sanitize_search(value['@value'])
      { 'searchPath' => attribute, "search-#{property}" => search_text }
    end

    def sanitize_search(search_text)
      search_text
        .gsub(' AND ', ' ')
        .gsub(/(\( | \))/, '')
    end

    def remove_prefix(value)
      return value.split(':')[1] unless value.match?(/^http/)

      value
    end
  end
end
