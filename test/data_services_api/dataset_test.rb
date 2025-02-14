# frozen_string_literal: true

require './test/minitest_helper'

class MockNotifications
  attr_reader :instrumentations

  def initialize
    @instrumentations = []
  end

  def instrument(*args)
    @instrumentations << args
  end
end

class MockLogger
  attr_reader :messages

  def initialize
    @messages = Hash.new { |h, k| h[k] = [] }
  end

  def info(message, &block)
    @messages[:info] << [message, block&.call]
  end
end

describe 'DataServiceApi::Dataset' do
  let(:api_url) do
    ENV.fetch('API_SERVICE_URL', 'http://localhost:8888')
  end

  let :mock_logger do
    MockLogger.new
  end

  before do
    instrumenter = MockNotifications.new
    VCR.insert_cassette(name, record: :new_episodes)

    mock_logger.expects(:info).at_least(0)

    @dataset = DataServicesApi::Service.new(url: api_url, instrumenter: instrumenter, logger: mock_logger).dataset('ukhpi')
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
        { '@and' => [{ 'ukhpi:refMonth' => { '@ge' => { :@value => '2019-01', :@type => 'http://www.w3.org/2001/XMLSchema#gYearMonth' } } }, { 'ukhpi:refRegion' => { '@eq' => { :@id => 'http://landregistry.data.gov.uk/id/region/united-kingdom' } } }], '@sort' => [{ '@down' => 'ukhpi:refMonth' }], '@limit' => 1 }
      end

      def to_json(*_args)
        terms.to_json
      end
    end.new

    json = @dataset.query(query)
    _(json).wont_be_nil
    _(json.size).must_be :>, 0
  end
end
