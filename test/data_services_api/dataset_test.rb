# frozen_string_literal: true

require './test/minitest_helper'

class MockNotifications
  attr_reader :instrumentations

  def initialize
    @instrumentations = []
  end

  def instrument(*args)
    @instrumentations << args
    yield if block_given?
  end
end

describe 'DataServiceApi::Dataset' do
  let(:api_url) do
    ENV.fetch('API_SERVICE_URL', 'http://localhost:8888')
  end

  before do
    mock_notifier = MockNotifications.new
    VCR.insert_cassette(name, record: :new_episodes)

    @dataset = DataServicesApi::Service.new(url: api_url, instrumenter: mock_notifier).dataset('ukhpi')
  end

  after do
    VCR.eject_cassette
  end

  it 'should have a reference to the service object' do
    _(@dataset.service).wont_be_nil
    _(@dataset.service.url).wont_be_nil
  end

  it 'should accept a query and return the result' do
    query = Class.new do
      def terms
        { '@and' => [
          { 'ukhpi:refMonth' => { '@ge' => { :@value => '2019-01', :@type => 'http://www.w3.org/2001/XMLSchema#gYearMonth' } } },
          { 'ukhpi:refRegion' => { '@eq' => { :@id => 'http://landregistry.data.gov.uk/id/region/united-kingdom' } } }
        ], '@sort' => [
          { '@down' => 'ukhpi:refMonth' }
        ], '@limit' => 1 }
      end

      def to_json(*_args)
        terms.to_json
      end
    end.new

    # Ensure the query responds to the expected methods
    _(query).must_respond_to :terms
    _(query).must_respond_to :to_json
    # Ensure the query terms are a Hash
    _(query.terms).must_be_kind_of Hash

    # Perform the query
    json = @dataset.query(query)
    # Check the response
    _(json).wont_be_nil
    _(json.size).must_be :>, 0
  end

  it 'should describe its own structure as a set of aspects' do
    skip('this endpoint doesn''t exist')
    aspects = @dataset.structure

    _(aspects).wont_be_empty
    _(aspects.first).must_be_instance_of(DataServicesApi::Aspect)
  end

  it 'should accept a URI and return an RDF description' do
    skip('this endpoint doesn''t exist')
    description = @dataset.describe('http://landregistry.data.gov.uk/id/region/south-east')

    _(description).wont_be_nil
  end
end
