# frozen_string_literal: true

require './test/minitest_helper'

describe 'DataServicesApi::QueryResult' do
  let(:rows) { [{ '@id' => 'http://example.com/1' }, { '@id' => 'http://example.com/2' }] }
  let(:result) { DataServicesApi::QueryResult.new(rows, { 'limit' => 2 }) }

  it 'should behave as the array of rows' do
    _(result).must_equal rows
    _(result.size).must_equal 2
    _(result.first).must_equal rows.first
  end

  it 'should expose the meta' do
    _(result.meta).must_equal('limit' => 2)
  end

  it 'should default the meta to an empty Hash' do
    _(DataServicesApi::QueryResult.new(rows).meta).must_equal({})
  end

  it 'should serialise to JSON as the rows alone' do
    _(JSON.parse(result.to_json)).must_equal rows
  end
end
