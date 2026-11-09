# frozen_string_literal: true

require './test/minitest_helper'

describe 'DataServicesApi::SapiNTConverter' do
  let(:dsapi_query) do
    '{
      "@json_mode": "compact",
      "@and": [
        {
          "ppd:propertyAddress": {
            "@search": {
              "@value": "( Cheltenham AND Road )",
              "@property": "lrcommon:street",
              "@limit": 3000000
            }
          }
        },
        {
          "ppd:propertyAddress": {
            "@search": {
              "@value": "( Bristol )",
              "@property": "lrcommon:town",
              "@limit": 3000000
            }
          }
        },
        {
          "ppd:newBuild": {
            "@oneof": [
              {
                "@value": "false",
                "@type": "xsd:boolean"
              }
            ]
          }
        },
        {
          "ppd:transactionCategory": {
            "@oneof": [
              {
                "@id": "ppd:standardPricePaidTransaction"
              }
            ]
          }
        }
      ],
      "@count": true,
      "@limit": 10000
    }'
  end

  let(:sapint_query) do
    {
      'searchPath' => 'propertyAddress',
      'search-street' => 'Cheltenham Road',
      'search-town' => 'Bristol',
      'newBuild' => 'false',
      'transactionCategory' => 'standardPricePaidTransaction',
      '_count' => '@id',
      '_limit' => 10_000
    }
  end

  let(:sapi_conv) do
    DataServicesApi::SapiNTConverter.new(dsapi_query)
  end

  it 'should convert the DSAPI query to SAPINT' do
    _(sapi_conv.to_sapint_query).must_equal sapint_query
  end

  it 'should convert DSAPI count to SAPINT count' do
    _(sapi_conv.send(:sapint_query, '@count', true)).must_equal('_count' => '@id')
  end

  it 'should convert DSAPI and to SAPINT format' do
    and_json = JSON.parse(dsapi_query)['@and']

    _(sapi_conv.send(:and_list, and_json)).must_equal(
      sapint_query.map do |key, value|
        [key, value] unless %w[_count _limit].include?(key)
      end.compact.to_h
    )
  end

  it 'should convert DSAPI relation to SAPINT' do
    _(sapi_conv.send(:relation, '@ge', 'exampleAttribute', 28)).must_equal('mineq-exampleAttribute' => 28)
  end

  it 'should sanitize the search text before storing it as param' do
    _(sapi_conv.send(:sanitize_search, '( Bristol AND Road )')).must_equal 'Bristol Road'
  end

  it 'should remove prefix if string is not a URL' do
    _(sapi_conv.send(:remove_prefix, 'ppd:exampleAttribute')).must_equal 'exampleAttribute'
    _(sapi_conv.send(:remove_prefix, 'https://google.com')).must_equal 'https://google.com'
  end

  it 'should keep a value with no prefix as it is' do
    _(sapi_conv.send(:remove_prefix, 'detached')).must_equal 'detached'
  end

  it 'should keep everything after the first colon' do
    _(sapi_conv.send(:remove_prefix, 'a:b:c')).must_equal 'b:c'
  end

  describe 'a parameter without a value' do
    def convert(and_item)
      DataServicesApi::SapiNTConverter.new({ '@and' => [and_item] }.to_json).to_sapint_query
    end

    it 'should raise ArgumentError for a null comparison value' do
      error = _ { convert('ppd:pricePaid' => { '@ge' => nil }) }.must_raise ArgumentError
      _(error.message).must_include 'pricePaid'
    end

    it 'should raise ArgumentError for a null typed comparison value' do
      error = _ { convert('ppd:pricePaid' => { '@ge' => { '@value' => nil, '@type' => 'xsd:decimal' } }) }
              .must_raise ArgumentError
      _(error.message).must_include 'pricePaid'
    end

    it 'should raise ArgumentError for a null equality value' do
      error = _ { convert('ppd:propertyType' => { '@eq' => { '@value' => nil } }) }.must_raise ArgumentError
      _(error.message).must_include 'propertyType'
    end

    it 'should raise ArgumentError for an empty equality value' do
      error = _ { convert('ppd:propertyType' => { '@eq' => '' }) }.must_raise ArgumentError
      _(error.message).must_include 'propertyType'
    end

    it 'should raise ArgumentError for a missing search value' do
      error = _ { convert('ppd:propertyAddress' => { '@search' => { '@property' => 'lrcommon:town' } }) }
              .must_raise ArgumentError
      _(error.message).must_include 'propertyAddress'
    end

    it 'should send an identifier that is only a prefix as it is' do
      _(convert('ppd:estateType' => { '@eq' => { '@id' => 'lrcommon:' } })).must_equal('estateType' => 'lrcommon:')
    end

    it 'should raise ArgumentError for a null limit' do
      error = _ { DataServicesApi::SapiNTConverter.new('{"@limit": null}').to_sapint_query }
              .must_raise ArgumentError
      _(error.message).must_include '@limit'
    end

    it 'should still send an unprefixed identifier as it is' do
      _(convert('ppd:propertyType' => { '@eq' => { '@id' => 'detached' } })).must_equal('propertyType' => 'detached')
    end
  end
end
