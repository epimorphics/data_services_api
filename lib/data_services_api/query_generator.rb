module DataServicesApi

  # Generate Data Service API queries, and serialize as JSON
  class QueryGenerator
    attr_reader :terms

    def initialize( terms = nil )
      @terms = terms || {}
    end

    def to_json
      @terms.to_json
    end

    def eq( attribute, value )
      relational( "@eq", attribute, value )
    end

    def eq_any_uri( attribute, uris )
      eq_any( attribute, uris, "@id" )
    end

    def eq_any_value( attribute, values )
      eq_any( attribute, values, "@value" )
    end

    def ge( attribute, value )
      relational( "@ge", attribute, value )
    end

    def gt( attribute, value )
      relational( "@gt", attribute, value )
    end

    def le( attribute, value )
      relational( "@le", attribute, value )
    end

    def lt( attribute, value )
      relational( "@lt", attribute, value )
    end

    def op( op, attribute, value )
      op = op.is_a?( Symbol ) ? "@#{op}" : op
      raise NameError.new( "Unrecognised operation #{op}" ) unless %w(@eq @ge @gt @le @lt).include?( op )
      relational( op, attribute, value )
    end

    def sort( up_or_down, attribute )
      raise "Unexpected sort order: #{up_or_down}" unless [:up, :down].include?( up_or_down )

      sort = (@terms["@sort"] || []) << {"@#{up_or_down}" => attribute}
      QueryGenerator.new( @terms.merge( {"@sort" => sort} ) )
    end

    def search( pattern )
      QueryGenerator.new( @terms.merge( {"@search" => pattern} ) )
    end

    def search_property( property, pattern )
      QueryGenerator.new( @terms.merge( {"@search" => {"@value" => pattern, "@property" => property}} ) )
    end

    def search_aspect( aspect, pattern )
      QueryGenerator.new( @terms.merge( {aspect => {"@search" => pattern}} ) )
    end

    def search_aspect_property( aspect, property, pattern )
      QueryGenerator.new( @terms.merge( {aspect => {"@search" => {"@value" => pattern, "@property" => property}}} ) )
    end

    private

    def relational( rel, attribute, value )
      term = {rel => value}
      if t = @terms[attribute]
        term = t.merge( term )
      end
      QueryGenerator.new( @terms.merge( {attribute => term} ))
    end

    def eq_any( attribute, values, value_type )
      eq_clauses = values.map {|v| {value_type => v} }
      QueryGenerator.new( @terms.merge( {attribute => {"@oneof" => eq_clauses}} ) )
    end


  end
end
