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

describe 'DataServicesAPI::Service' do
  let(:api_url) do
    ENV.fetch('API_SERVICE_URL', 'http://localhost:8888')
  end

  before do
    mock_notifier = MockNotifications.new
    VCR.insert_cassette(name, record: :new_episodes)
    @service = DataServicesApi::Service.new(url: api_url, instrumenter: mock_notifier)
  end

  after do
    VCR.eject_cassette
  end

  it 'should return the service URL' do
    mock_notifier = MockNotifications.new
    service = DataServicesApi::Service.new(url: 'https://wimbledon.com', instrumenter: mock_notifier)
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

    service = DataServicesApi::Service.new(url: api_url, instrumenter: mock_notifier)
    json = service.api_get_json("#{api_url}/landregistry/id/ukhpi", { '_limit' => 1 })
    _(json).wont_be_nil
    _(json['meta']).wont_be_nil
  end

  it 'should instrument an API call' do
    mock_notifier = MockNotifications.new

    DataServicesApi::Service
      .new(url: api_url, instrumenter: mock_notifier)
      .api_get_json("#{api_url}/landregistry/id/ukhpi", { '_limit' => 1 })

    event_names = mock_notifier.instrumentations.map(&:first)
    _(event_names).must_include 'response.data_services_api'
    _(event_names).must_include 'query_result.data_services_api'
  end

  it 'should instrument a failed API call' do
    mock_api_url = 'http://localhost:8765'
    mock_notifier = MockNotifications.new

    _ do
      DataServicesApi::Service
        .new(url: mock_api_url, instrumenter: mock_notifier)
        .api_get_json("#{mock_api_url}/landregistry/id/ukhpi", { '_limit' => 1 })
    end.must_raise

    event_names = mock_notifier.instrumentations.map(&:first)
    _(event_names).must_include 'connection_failure.data_services_api'
  end

  it 'should also instrument an API Service Exception' do
    mock_notifier = MockNotifications.new

    error = _ do
      DataServicesApi::Service
        .new(url: api_url, instrumenter: mock_notifier)
        .api_get_json("#{api_url}/ceci/nest/pas/une/page", { '_limit' => 1 })
    end.must_raise DataServicesApi::ServiceException

    _(error.status).must_equal 404

    _, payload = mock_notifier.instrumentations.find { |n, _| n == 'service_exception.data_services_api' }
    _(payload).wont_be_nil
    _(payload[:status]).must_equal 404
    _(payload[:query_string]).must_equal '_limit=1'
  end

  it 'should include the returned row count in the query result instrumentation' do
    mock_notifier = MockNotifications.new

    DataServicesApi::Service
      .new(url: api_url, instrumenter: mock_notifier)
      .api_get_json("#{api_url}/landregistry/id/ukhpi", { '_limit' => 1 })

    _, payload = mock_notifier.instrumentations.find { |name, _| name == 'query_result.data_services_api' }
    _(payload).wont_be_nil
    _(payload[:returned_rows]).wont_be_nil
  end

  it 'should correctly receive a duration in microseconds' do
    mock_notifier = MockNotifications.new

    DataServicesApi::Service
      .new(url: api_url, instrumenter: mock_notifier)
      .api_get_json("#{api_url}/landregistry/id/ukhpi", { '_limit' => 1 })

    _, payload = mock_notifier.instrumentations.find { |name, _| name == 'response.data_services_api' }
    _(payload).wont_be_nil
    _(payload[:duration]).must_be :>, 0
  end

  it 'should return a list of defined datasets' do
    datasets = @service.datasets

    _(datasets.size).must_be :>, 0
    _(datasets.first).must_be_instance_of(DataServicesApi::Dataset)
  end

  it 'should instrument each retry attempt before giving up on a failed connection' do
    mock_api_url = 'http://localhost:8765'
    mock_notifier = MockNotifications.new

    _ do
      DataServicesApi::Service
        .new(url: mock_api_url, instrumenter: mock_notifier,
             connection_failed_retry_options: { max: 2, interval: 0 })
        .api_get_json("#{mock_api_url}/landregistry/id/ukhpi", { '_limit' => 1 })
    end.must_raise

    retries = mock_notifier.instrumentations.select { |entry| entry.first == 'retry.data_services_api' }
    _(retries.size).must_equal 2
    _(retries.map { |_, payload| payload[:retry_count] }).must_equal [1, 2]
  end
end
