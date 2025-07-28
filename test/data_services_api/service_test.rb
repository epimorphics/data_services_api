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
    ENV.fetch('API_SERVICE_URL', 'http://localhost:8888')
  end

  let :mock_logger do
    MockLogger.new
  end

  before do
    mock_notifier = MockNotifications.new
    VCR.insert_cassette(name, record: :new_episodes)
    @service = DataServicesApi::Service.new(url: api_url, instrumenter: mock_notifier, logger: mock_logger)
  end

  after do
    VCR.eject_cassette
  end

  it 'should return the service URL' do
    mock_notifier = MockNotifications.new
    service = DataServicesApi::Service.new(url: 'https://wimbledon.com', instrumenter: mock_notifier, logger: mock_logger)
    _(service.url).must_equal('https://wimbledon.com')
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
    mock_notifier = MockNotifications.new

    service = DataServicesApi::Service.new(url: api_url, instrumenter: mock_notifier, logger: mock_logger)
    json = service.api_get_json("#{api_url}/landregistry/id/ukhpi", { '_limit' => 1 })
    _(json).wont_be_nil
    _(json['meta']).wont_be_nil
  end

  it 'should instrument an API call' do
    mock_notifier = MockNotifications.new

    DataServicesApi::Service
      .new(url: api_url, instrumenter: mock_notifier, logger: mock_logger)
      .api_get_json("#{api_url}/landregistry/id/ukhpi", { '_limit' => 1 })

    instrumentations = mock_notifier.instrumentations
    _(instrumentations.size).must_equal 1
    _(instrumentations.first.first).must_equal 'response.api'
  end

  it 'should instrument a failed API call' do
    mock_api_url = 'http://localhost:8765'
    mock_notifier = MockNotifications.new
    mock_logger = MockLogger.new

    _ do
      DataServicesApi::Service
        .new(url: mock_api_url, instrumenter: mock_notifier, logger: mock_logger)
        .api_get_json("#{mock_api_url}/landregistry/id/ukhpi", { '_limit' => 1 })
    end.must_raise

    instrumentations = mock_notifier.instrumentations
    _(instrumentations.size).must_equal 1
    _(instrumentations.first.first).must_equal 'connection_failure.api'
  end

  it 'should also instrument an API Service Exception' do
    mock_notifier = MockNotifications.new
    mock_logger = MockLogger.new

    _ do
      DataServicesApi::Service
        .new(url: api_url, instrumenter: mock_notifier, logger: mock_logger)
        .api_get_json("#{api_url}/ceci/nest/pas/une/page", { '_limit' => 1 })
    end.must_raise

    instrumentations = mock_notifier.instrumentations
    _(instrumentations.size).must_equal 1
    _(instrumentations.first.first).must_equal 'service_exception.api'
  end

  it 'should log the call to the data API' do
    mock_notifier = MockNotifications.new
    mock_logger = MockLogger.new

    DataServicesApi::Service
      .new(url: api_url, instrumenter: mock_notifier, logger: mock_logger)
      .api_get_json("#{api_url}/landregistry/id/ukhpi", { '_limit' => 1 })

    # @TODO: add specific constraints on received log messages
    _(mock_logger.messages).wont_be_empty
  end

  it 'should correctly receive a duration in microseconds' do
    mock_notifier = MockNotifications.new
    mock_logger = MockLogger.new

    DataServicesApi::Service
      .new(url: api_url, instrumenter: mock_notifier, logger: mock_logger)
      .api_get_json("#{api_url}/landregistry/id/ukhpi", { '_limit' => 1 })

    _(mock_logger).wont_be_nil

    # Check the last logged message for duration
    mock_log = mock_logger.messages[:info].last
    _(mock_log).wont_be_nil
    _(mock_log.size).must_equal 2

    json = mock_log.first
    duration = JSON.parse(json)['request_time']

    if duration
      _(duration.to_f).must_be :>, 0
      assert_kind_of(String, duration)
    end
  end
end
