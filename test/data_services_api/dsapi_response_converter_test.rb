# frozen_string_literal: true

require './test/minitest_helper'

describe 'DataServicesApi::DSAPIResponseConverter' do
  describe 'PPD' do
    let(:ppd_sapint_items) do
      [
        {
          '@id' => 'http://landregistry.data.gov.uk/data/ppi/transaction/F799167A-933D-4A33-8823-01CB7CFD43BB/current',
          'propertyAddress' => {
            '@id' => 'http://landregistry.data.gov.uk/data/ppi/address/4c03e3251cddc45cb6bbeeed2524805be5c75c6b',
            'county' => 'SOUTH YORKSHIRE',
            'district' => 'SHEFFIELD',
            'locality' => 'SOTHALL',
            'paon' => '5',
            'postcode' => 'S20 2QW',
            'street' => 'MILBURN COURT',
            'town' => 'SHEFFIELD'
          },
          'newBuild' => false,
          'estateType' => { '@id' => 'http://landregistry.data.gov.uk/def/common/freehold' },
          'transactionCategory' => { '@id' => 'http://landregistry.data.gov.uk/def/ppi/standardPricePaidTransaction' },
          'pricePaid' => 41_950,
          'transactionDate' => '1995-06-30',
          'propertyType' => { '@id' => 'http://landregistry.data.gov.uk/def/common/semi-detached' },
          'hasTransaction' => { '@id' => 'http://landregistry.data.gov.uk/data/ppi/transaction/F799167A-933D-4A33-8823-01CB7CFD43BB' },
          'transactionId' => 'F799167A-933D-4A33-8823-01CB7CFD43BB',
          'recordStatus' => { '@id' => 'http://landregistry.data.gov.uk/def/ppi/add' }
        }
      ]
    end

    let(:ppd_dsapi_items) do
      [
        {
          'ppd:propertyAddressPostcode' => 'S20 2QW',
          'ppd:transactionCategory' => 'http://landregistry.data.gov.uk/def/ppi/standardPricePaidTransaction',
          'ppd:propertyAddressCounty' => 'SOUTH YORKSHIRE',
          'ppd:estateType' => 'http://landregistry.data.gov.uk/def/common/freehold',
          'ppd:propertyAddressPaon' => '5',
          'ppd:recordStatus' => 'http://landregistry.data.gov.uk/def/ppi/add',
          'ppd:propertyAddressStreet' => 'MILBURN COURT',
          'ppd:transactionId' => 'F799167A-933D-4A33-8823-01CB7CFD43BB',
          'ppd:propertyAddressTown' => 'SHEFFIELD',
          'ppd:pricePaid' => 41_950,
          'ppd:propertyAddressLocality' => 'SOTHALL',
          'ppd:hasTransaction' => 'http://landregistry.data.gov.uk/data/ppi/transaction/F799167A-933D-4A33-8823-01CB7CFD43BB',
          'ppd:transactionDate' => '1995-06-30',
          'ppd:propertyAddress' => 'http://landregistry.data.gov.uk/data/ppi/address/4c03e3251cddc45cb6bbeeed2524805be5c75c6b',
          '@id' => 'http://landregistry.data.gov.uk/data/ppi/transaction/F799167A-933D-4A33-8823-01CB7CFD43BB/current',
          'ppd:newBuild' => false,
          'ppd:propertyAddressDistrict' => 'SHEFFIELD',
          'ppd:propertyType' => 'http://landregistry.data.gov.uk/def/common/semi-detached'
        }
      ]
    end

    let(:ppd_resp_conv) do
      DataServicesApi::DSAPIResponseConverter.new(
        {
          'items' => ppd_sapint_items
        },
        'ppd',
        true
      )
    end

    it 'should convert the SAPINT response format to DSAPI response format' do
      _(ppd_resp_conv.to_dsapi_response).must_equal ppd_dsapi_items
    end

    it 'should convert one SAPINT item to DSAPI format' do
      _(ppd_resp_conv.send(:to_dsapi_item, ppd_sapint_items[0])).must_equal ppd_dsapi_items[0]
    end

    it 'should convert some SAPINT json to DSAPI format' do
      actual_response = ppd_resp_conv.send(:to_dsapi_json, 'newBuild', ppd_sapint_items[0]['newBuild'])
      expected_response = { 'ppd:newBuild' => ppd_dsapi_items[0]['ppd:newBuild'] }

      _(actual_response).must_equal expected_response
    end

    it 'should convert SAPINT hash to DSAPI format' do
      actual_response = ppd_resp_conv.send(:to_dsapi_json, 'propertyAddress', 'county' => 'SOMERSET')
      expected_response = { 'ppd:propertyAddressCounty' => 'SOMERSET' }

      _(actual_response).must_equal expected_response
    end
  end

  describe 'UKHPI' do
    let(:ukhpi_sapint_items) do
      [
        {
          '@id' => 'http://landregistry.data.gov.uk/data/ukhpi/region/redcar-and-cleveland/month/2020-12',
          'refRegion' => {
            '@id' => 'http://landregistry.data.gov.uk/id/region/redcar-and-cleveland'
          },
          'refMonth' => '2020-12',
          'averagePrice' => 130_677,
          'housePriceIndex' => 112.07,
          'percentageAnnualChange' => 6.7,
          'percentageChange' => 1.81,
          'salesVolume' => 190,
          'averagePriceDetached' => 207_752,
          'housePriceIndexDetached' => 113.78,
          'percentageChangeDetached' => 1.73,
          'percentageAnnualChangeDetached' => 7.75,
          'averagePriceSemiDetached' => 129_589,
          'housePriceIndexSemiDetached' => 112.5,
          'percentageChangeSemiDetached' => 1.7,
          'percentageAnnualChangeSemiDetached' => 6.26,
          'averagePriceTerraced' => 98_119,
          'housePriceIndexTerraced' => 111.33,
          'percentageChangeTerraced' => 2.08,
          'percentageAnnualChangeTerraced' => 7.04,
          'averagePriceFlatMaisonette' => 66_077,
          'housePriceIndexFlatMaisonette' => 104.45,
          'percentageChangeFlatMaisonette' => 2.03,
          'percentageAnnualChangeFlatMaisonette' => 3.5,
          'averagePriceCash' => 119_886,
          'housePriceIndexCash' => 111.38,
          'percentageChangeCash' => 1.85,
          'percentageAnnualChangeCash' => 6.45,
          'salesVolumeCash' => 68,
          'averagePriceMortgage' => 137_008,
          'housePriceIndexMortgage' => 112.46,
          'percentageChangeMortgage' => 1.79,
          'percentageAnnualChangeMortgage' => 6.84,
          'salesVolumeMortgage' => 108,
          'averagePriceFirstTimeBuyer' => 116_039,
          'housePriceIndexFirstTimeBuyer' => 111.69,
          'percentageChangeFirstTimeBuyer' => 1.84,
          'percentageAnnualChangeFirstTimeBuyer' => 6.39,
          'averagePriceFormerOwnerOccupier' => 145_505,
          'housePriceIndexFormerOwnerOccupier' => 112.38,
          'percentageChangeFormerOwnerOccupier' => 1.78,
          'percentageAnnualChangeFormerOwnerOccupier' => 7.01,
          'averagePriceNewBuild' => 184_694,
          'housePriceIndexNewBuild' => 114.23,
          'percentageChangeNewBuild' => 1.33,
          'percentageAnnualChangeNewBuild' => 6.52,
          'salesVolumeNewBuild' => 11,
          'averagePriceExistingProperty' => 126_352,
          'housePriceIndexExistingProperty' => 111.87,
          'percentageChangeExistingProperty' => 1.88,
          'percentageAnnualChangeExistingProperty' => 6.57,
          'salesVolumeExistingProperty' => 179,
          'refPeriodStart' => '2020-12-01',
          'refPeriodDuration' => 1
        }
      ]
    end

    let(:ukhpi_dsapi_items) do
      [
        {
          'ukhpi:percentageChangeNewBuild' => [
            1.33
          ],
          'ukhpi:salesVolumeMortgage' => [
            108
          ],
          'ukhpi:percentageChangeDetached' => [
            1.73
          ],
          'ukhpi:housePriceIndexFirstTimeBuyer' => [
            111.69
          ],
          'ukhpi:averagePrice' => [
            130_677
          ],
          'ukhpi:refPeriodDuration' => [
            1
          ],
          'ukhpi:housePriceIndexTerraced' => [
            111.33
          ],
          'ukhpi:percentageAnnualChangeFlatMaisonette' => [
            3.5
          ],
          'ukhpi:averagePriceSemiDetached' => [
            129_589
          ],
          'ukhpi:housePriceIndexFlatMaisonette' => [
            104.45
          ],
          'ukhpi:averagePriceMortgage' => [
            137_008
          ],
          'ukhpi:averagePriceNewBuild' => [
            184_694
          ],
          'ukhpi:percentageAnnualChangeExistingProperty' => [
            6.57
          ],
          'ukhpi:averagePriceFormerOwnerOccupier' => [
            145_505
          ],
          'ukhpi:percentageAnnualChangeFirstTimeBuyer' => [
            6.39
          ],
          'ukhpi:averagePriceDetached' => [
            207_752
          ],
          'ukhpi:housePriceIndexCash' => [
            111.38
          ],
          'ukhpi:percentageAnnualChangeSemiDetached' => [
            6.26
          ],
          'ukhpi:percentageChangeMortgage' => [
            1.79
          ],
          'ukhpi:percentageChangeCash' => [
            1.85
          ],
          'ukhpi:refMonth' => {
            '@value' => '2020-12'
          },
          'ukhpi:percentageChangeSemiDetached' => [
            1.7
          ],
          'ukhpi:percentageChangeFormerOwnerOccupier' => [
            1.78
          ],
          'ukhpi:refRegion' => {
            '@id' => 'http://landregistry.data.gov.uk/id/region/redcar-and-cleveland'
          },
          'ukhpi:housePriceIndex' => [
            112.07
          ],
          'ukhpi:percentageAnnualChangeFormerOwnerOccupier' => [
            7.01
          ],
          'ukhpi:housePriceIndexExistingProperty' => [
            111.87
          ],
          'ukhpi:housePriceIndexMortgage' => [
            112.46
          ],
          'ukhpi:housePriceIndexSemiDetached' => [
            112.5
          ],
          'ukhpi:averagePriceExistingProperty' => [
            126_352
          ],
          'ukhpi:percentageAnnualChangeTerraced' => [
            7.04
          ],
          'ukhpi:percentageAnnualChangeMortgage' => [
            6.84
          ],
          'ukhpi:refPeriodStart' => [
            {
              '@value' => '2020-12-01'
            }
          ],
          'ukhpi:housePriceIndexDetached' => [
            113.78
          ],
          'ukhpi:percentageChange' => [
            1.81
          ],
          'ukhpi:salesVolume' => [
            190
          ],
          'ukhpi:percentageChangeTerraced' => [
            2.08
          ],
          'ukhpi:percentageChangeExistingProperty' => [
            1.88
          ],
          '@id' => 'http://landregistry.data.gov.uk/data/ukhpi/region/redcar-and-cleveland/month/2020-12',
          'ukhpi:averagePriceFirstTimeBuyer' => [
            116_039
          ],
          'ukhpi:percentageAnnualChangeCash' => [
            6.45
          ],
          'ukhpi:averagePriceCash' => [
            119_886
          ],
          'ukhpi:averagePriceTerraced' => [
            98_119
          ],
          'ukhpi:percentageAnnualChangeDetached' => [
            7.75
          ],
          'ukhpi:percentageAnnualChange' => [
            6.7
          ],
          'ukhpi:salesVolumeCash' => [
            68
          ],
          'ukhpi:averagePriceFlatMaisonette' => [
            66_077
          ],
          'ukhpi:salesVolumeNewBuild' => [
            11
          ],
          'ukhpi:salesVolumeExistingProperty' => [
            179
          ],
          'ukhpi:percentageAnnualChangeNewBuild' => [
            6.52
          ],
          'ukhpi:percentageChangeFlatMaisonette' => [
            2.03
          ],
          'ukhpi:housePriceIndexNewBuild' => [
            114.23
          ],
          'ukhpi:percentageChangeFirstTimeBuyer' => [
            1.84
          ],
          'ukhpi:housePriceIndexFormerOwnerOccupier' => [
            112.38
          ]
        }
      ]
    end

    let(:ukhpi_resp_conv) do
      DataServicesApi::DSAPIResponseConverter.new(
        {
          'items' => ukhpi_sapint_items
        },
        'ukhpi'
        # JSON mode here defaults to "complete" because it's not specified
      )
    end

    it 'should convert the SAPINT response format to DSAPI response format' do
      _(ukhpi_resp_conv.to_dsapi_response).must_equal ukhpi_dsapi_items
    end

    it 'should convert one SAPINT item to DSAPI format' do
      _(ukhpi_resp_conv.send(:to_dsapi_item, ukhpi_sapint_items[0])).must_equal ukhpi_dsapi_items[0]
    end

    it 'should convert some SAPINT json to DSAPI format' do
      actual_response = ukhpi_resp_conv.send(:to_dsapi_json, 'averagePrice', ukhpi_sapint_items[0]['averagePrice'])
      expected_response = { 'ukhpi:averagePrice' => ukhpi_dsapi_items[0]['ukhpi:averagePrice'] }

      _(actual_response).must_equal expected_response
    end

    it 'should convert SAPINT hash to DSAPI format' do
      actual_response = ukhpi_resp_conv.send(:to_dsapi_json, 'refRegion', '@id' => 'http://landregistry.data.gov.uk/id/region/redcar-and-cleveland')
      expected_response = { 'ukhpi:refRegion' => { '@id' => 'http://landregistry.data.gov.uk/id/region/redcar-and-cleveland' } }

      _(actual_response).must_equal expected_response
    end
  end
end
