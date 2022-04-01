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

describe 'DataServicesAPI::Service', vcr: true do
  let(:api_url) do
    ENV['API_URL'] || 'http://localhost:8888'
  end

  before do
    VCR.insert_cassette(name, record: :new_episodes)
    @service = DataServicesApi::Service.new
  end

  after do
    VCR.eject_cassette
  end

  it 'should return the service URL' do
    _(DataServicesApi::Service.new(url: 'https://wimbledon.com').url)
      .must_equal('https://wimbledon.com')
  end

  it 'should find a dataset by name' do
    dataset = @service.dataset('ukhpi')
    _(dataset.data_api).must_match %r{/landregistry/id/ukhpi}
  end

  it 'should raise if getting a dataset with no name' do
    _ do
      @service.dataset(nil)
    end.must_raise
  end

  it 'should retrieve JSON with HTTP GET' do
    mock_logger = MockLogger.new
    service = DataServicesApi::Service.new(url: 'http://localhost:8080', logger: mock_logger)
    json = service.api_get_json("#{api_url}/landregistry/id/ukhpi", { '_limit' => 1 })
    _(json).wont_be_nil
    _(json['meta']).wont_be_nil
  end

  it 'should instrument an API call' do
    instrumenter = MockNotifications.new
    mock_logger = MockLogger.new

    DataServicesApi::Service
      .new(url: api_url, instrumenter: instrumenter, logger: mock_logger)
      .api_get_json("#{api_url}/landregistry/id/ukhpi", { '_limit' => 1 })

    instrumentations = instrumenter.instrumentations
    _(instrumentations.size).must_equal 1
    _(instrumentations.first.first).must_equal 'response.api'
  end

  it 'should instrument a failed API call' do
    instrumenter = MockNotifications.new
    mock_logger = MockLogger.new

    _ do
      DataServicesApi::Service
        .new(url: 'http://localhost:8765', instrumenter: instrumenter, logger: mock_logger)
        .api_get_json('http://localhost:8765/landregistry/id/ukhpi', { '_limit' => 1 })
    end.must_raise

    instrumentations = instrumenter.instrumentations
    _(instrumentations.size).must_equal 1
    _(instrumentations.first.first).must_equal 'connection_failure.api'
  end

  it 'should instrument a failed API call' do
    instrumenter = MockNotifications.new
    mock_logger = MockLogger.new

    _ do
      DataServicesApi::Service
        .new(url: api_url, instrumenter: instrumenter, logger: mock_logger)
        .api_get_json("#{api_url}/ceci/nest/pas/une/page", { '_limit' => 1 })
    end.must_raise

    instrumentations = instrumenter.instrumentations
    _(instrumentations.size).must_equal 2
    _(instrumentations[0].first).must_equal 'response.api'
    _(instrumentations[1].first).must_equal 'service_exception.api'
  end

  it 'should log the call to the data API' do
    logger = MockLogger.new

    DataServicesApi::Service
      .new(url: api_url, logger: logger)
      .api_get_json("#{api_url}/landregistry/id/ukhpi", { '_limit' => 1 })

    # @TODO: add specific constraints on received log messages
    _(logger.messages).wont_be_empty
  end
end
