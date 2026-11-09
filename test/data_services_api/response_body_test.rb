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

describe 'a response body the gem does not expect' do
  include WebMock::API

  let(:api_url) { 'http://stubbed-api.test' }
  let(:data_api) { "#{api_url}/landregistry/id/ukhpi" }
  let(:notifier) { MockNotifications.new }
  let(:dataset) { DataServicesApi::Service.new(url: api_url, instrumenter: notifier).dataset('ukhpi') }

  let(:query) do
    Class.new do
      def terms
        { '@limit' => 1 }
      end

      def to_json(*_args)
        terms.to_json
      end
    end.new
  end

  let(:item) { { '@id' => 'http://example.com/1', 'refMonth' => '2020-12' } }

  def stub_api(path, body, headers = {})
    stub_request(:get, /\A#{Regexp.escape(path)}(\?.*)?\z/).to_return(status: 200, body:, headers:)
  end

  def event_names
    notifier.instrumentations.map(&:first)
  end

  def response_payload
    notifier.instrumentations.find { |name, _| name == 'response.data_services_api' }&.last
  end

  def service_exception_payload
    notifier.instrumentations.find { |name, _| name == 'service_exception.data_services_api' }&.last
  end

  def must_raise_service_exception(body, &)
    error = _(&).must_raise DataServicesApi::ServiceException

    _(error.status).must_equal 200
    _(error.service_message).must_equal body
    must_fire_service_exception_only
    error
  end

  def must_fire_service_exception_only
    _(event_names).must_include 'service_exception.data_services_api'
    _(event_names).wont_include 'response.data_services_api'
    _(service_exception_payload[:status]).must_equal 200
  end

  after do
    WebMock.reset!
  end

  it 'should raise ServiceException for an HTML page served as text/html' do
    body = '<html><body>Down for maintenance</body></html>'
    stub_api(data_api, body, 'Content-Type' => 'text/html')

    must_raise_service_exception(body) { dataset.query(query) }
  end

  it 'should raise ServiceException for a body with no content type that is not JSON' do
    body = '<html></html>'
    stub_api(data_api, body)

    must_raise_service_exception(body) { dataset.query(query) }
  end

  it 'should parse a JSON body with no content type' do
    stub_api(data_api, { 'items' => [item] }.to_json)

    _(dataset.query(query).size).must_equal 1
  end

  it 'should raise ServiceException for a JSON object without items from Dataset#query' do
    body = { 'error' => 'something went wrong' }.to_json
    stub_api(data_api, body, 'Content-Type' => 'application/json')

    error = must_raise_service_exception(body) { dataset.query(query) }

    _(error.message).must_equal 'Response body has no items array'
  end

  it 'should raise ServiceException for a JSON object without items from Service#api_get_json' do
    body = { 'error' => 'something went wrong' }.to_json
    stub_api(data_api, body, 'Content-Type' => 'application/json')
    service = DataServicesApi::Service.new(url: api_url, instrumenter: notifier)

    error = must_raise_service_exception(body) { service.api_get_json(data_api, {}) }

    _(error.message).must_equal 'Response body has no items array'
  end

  it 'should return a JSON object without items from Service#api_get_explain_json' do
    body = { 'meta' => {}, 'sparql' => 'SELECT ...' }
    stub_api(data_api, body.to_json, 'Content-Type' => 'application/json')
    service = DataServicesApi::Service.new(url: api_url, instrumenter: notifier)

    _(service.api_get_explain_json(data_api, {})).must_equal body
  end

  it 'should raise ServiceException for an empty body' do
    stub_api(data_api, '', 'Content-Type' => 'application/json')

    error = must_raise_service_exception('') { dataset.query(query) }

    _(error.message).must_equal 'Response body is not a JSON object or array'
  end

  it 'should raise ServiceException for a JSON scalar' do
    stub_api("#{data_api}/explain", '"ok"', 'Content-Type' => 'application/json')

    must_raise_service_exception('"ok"') { dataset.explain(query) }
  end

  it 'should still return the converted rows from a valid response, firing only response' do
    stub_api(data_api, { 'meta' => {}, 'items' => [item] }.to_json, 'Content-Type' => 'application/json')

    rows = dataset.query(query)

    _(rows).must_equal [{ '@id' => 'http://example.com/1', 'ukhpi:refMonth' => { '@value' => '2020-12' } }]
    _(event_names).must_include 'response.data_services_api'
    _(event_names).wont_include 'service_exception.data_services_api'
    _(response_payload[:row_count]).must_equal 1
  end

  it 'should return the API meta alongside the rows from Dataset#query' do
    meta = { 'limit' => 100_000 }
    stub_api(data_api, { 'meta' => meta, 'items' => [item] }.to_json, 'Content-Type' => 'application/json')

    rows = dataset.query(query)

    _(rows).must_be_kind_of DataServicesApi::QueryResult
    _(rows.meta).must_equal meta
  end

  it 'should still return an explain response, which has no items, as it is' do
    explain = { 'meta' => {}, 'sparql' => 'SELECT ...' }
    stub_api("#{data_api}/explain", explain.to_json, 'Content-Type' => 'application/json')

    _(dataset.explain(query)).must_equal explain
    _(event_names).must_include 'response.data_services_api'
    _(event_names).wont_include 'service_exception.data_services_api'
    _(response_payload).must_include :row_count
    _(response_payload[:row_count]).must_be_nil
  end
end
