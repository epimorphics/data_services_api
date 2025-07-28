# frozen_string_literal: true

module DataServicesApi
  # Generate Data Service API queries, and serialize as JSON
  class QueryGenerator
    OPERATIONS = %w[@eq @ge @gt @le @lt].freeze

    attr_reader :terms

    def initialize(initial_terms = nil)
      @terms = initial_terms || {}
    end

    def to_json(*_args)
      @terms.to_json
    end

    def compact_json
      QueryGenerator.new(@terms.merge('@json_mode' => 'compact'))
    end

    def eq(attribute, value)
      relational('@eq', attribute, value)
    end

    def eq_any_uri(attribute, uris, options = {})
      eq_any(attribute, uris, '@id', options)
    end

    def eq_any_value(attribute, values, options = {})
      eq_any(attribute, values, '@value', options)
    end

    def ge(attribute, value)
      relational('@ge', attribute, value)
    end

    def gt(attribute, value)
      relational('@gt', attribute, value)
    end

    def le(attribute, value)
      relational('@le', attribute, value)
    end

    def lt(attribute, value)
      relational('@lt', attribute, value)
    end

    def op(oper, attribute, value)
      oper = "@#{oper}" if oper.is_a?(Symbol)
      raise NameError, "Unrecognised operation #{oper}" unless OPERATIONS.include?(oper)

      relational(oper, attribute, value)
    end

    def sort(up_or_down, attribute)
      raise "Unexpected sort order: #{up_or_down}" unless %i[up down].include?(up_or_down)

      sort = (@terms['@sort'] || []) << { "@#{up_or_down}" => attribute }
      QueryGenerator.new(@terms.merge('@sort' => sort))
    end

    def search(pattern)
      QueryGenerator.new(merge_terms('@search' => pattern))
    end

    def search_property(property, pattern, options = {})
      search_options = { '@value' => pattern, '@property' => property }.merge(options)
      QueryGenerator.new(merge_terms('@search' => search_options))
    end

    def search_aspect(aspect, pattern)
      QueryGenerator.new(merge_terms(aspect => { '@search' => pattern }))
    end

    def search_aspect_property(aspect, property, pattern, options = {})
      search_options = { '@value' => pattern, '@property' => property }.merge(options)
      QueryGenerator.new(merge_terms(aspect => { '@search' => search_options }))
    end

    def matches(aspect, pattern, options = {})
      if options[:flags]
        QueryGenerator.new(merge_terms(aspect => { '@matches' => [pattern, options[:flags]] }))
      else
        QueryGenerator.new(merge_terms(aspect => { '@matches' => pattern }))
      end
    end

    def limit(lim)
      QueryGenerator.new(@terms.merge('@limit' => lim))
    end

    def offset(num)
      QueryGenerator.new(@terms.merge('@offset' => num))
    end

    def count_only
      QueryGenerator.new(@terms.merge('@count' => true))
    end

    private

    def relational(rel, attribute, value)
      term = { rel => as_typed_value(value) }
      if (t = @terms[attribute])
        term = t.merge(term)
      end
      QueryGenerator.new(merge_terms(attribute => term))
    end

    def eq_any(attribute, values, value_type, options)
      eq_clauses = values.map { |v| { value_type => v } }
      eq_clauses.each { |eq| eq['@type'] = options[:type] } if options[:type]
      QueryGenerator.new(merge_terms(attribute => { '@oneof' => eq_clauses }))
    end

    def as_typed_value(value)
      case value
      when Date
        { '@value' => value, '@type' => 'xsd:date' }
      else
        value
      end
    end

    def merge_terms(term)
      @terms.merge('@and' => ((@terms['@and'] || []) + [term]))
    end
  end
end
