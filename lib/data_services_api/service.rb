# frozen_string_literal: true

require 'faraday'

module DataServicesApi
  # Denotes the encapsulated DataServicesAPI service
  class Service # rubocop:disable Metrics/ClassLength
    attr_reader :instrumenter, :url

    DEFAULT_CONNECTION_FAILED_RETRY_OPTIONS = {
      max: 4,
      interval: 0.5,
      interval_randomness: 0.25,
      backoff_factor: 2,
      exceptions: [Faraday::ConnectionFailed]
    }.freeze

    DEFAULT_TIMEOUT_RETRY_OPTIONS = {
      max: 2,
      interval: 0.25,
      interval_randomness: 0.5,
      backoff_factor: 2,
      exceptions: [Faraday::TimeoutError]
    }.freeze

    DEFAULT_FARADAY_LOGGER_OPTIONS = {
      headers: false,
      bodies: false,
      errors: false,
      log_level: :debug
    }.freeze

    DEFAULT_CONNECTION_TIMEOUT_SECONDS = 600

    def initialize(config = {}) # rubocop:disable Metrics/MethodLength
      @instrumenter = config[:instrumenter] || (in_rails? && ActiveSupport::Notifications)
      @faraday_logger = config[:faraday_logger]
      @faraday_logger_options = DEFAULT_FARADAY_LOGGER_OPTIONS.merge(
        config[:faraday_logger_options] || {}
      )
      @url = config[:url]
      @connection_timeout = config[:connection_timeout] || DEFAULT_CONNECTION_TIMEOUT_SECONDS
      @connection_failed_retry_options = DEFAULT_CONNECTION_FAILED_RETRY_OPTIONS.merge(
        config[:connection_failed_retry_options] || {}
      )
      @timeout_retry_options = DEFAULT_TIMEOUT_RETRY_OPTIONS.merge(
        config[:timeout_retry_options] || {}
      )
    end

    def datasets
      api_get_json('/dataset', {}).map { |json| Dataset.new(json, self) }
    end

    def dataset(name)
      raise 'Dataset name is required' unless name

      endpoint = {
        'data-api' => "#{@url}/landregistry/id/#{name}",
        'dataset' => name
      }
      Dataset.new(endpoint, self)
    end

    def api_get_json(api, params, options = {})
      get_json(as_http_api(api), params, options)
    end

    def api_post_json(api, json)
      post_json(as_http_api(api), json)
    end

    private

    # Get parsed JSON from the given URL
    def get_json(http_url, params, options) # rubocop:disable Metrics/MethodLength
      response = get_from_api(http_url, 'application/json', params, options)
      response_body = response.body
      returned_rows = response_body['items'] ? response_body['items'].size : 0

      instrumenter&.instrument(
        'query_result.data_services_api',
        path: URI.parse(http_url).path,
        method: response.env.method.upcase,
        status: response.status,
        returned_rows:
      )

      response_body
    end

    def get_from_api(http_url, accept_headers, params, options)
      perform_request(http_url) do |conn|
        conn.get do |req|
          req.headers['X-Request-Id'] = Thread.current[:request_id] if Thread.current[:request_id]
          req.headers['Accept'] = accept_headers
          req.options.params_encoder = Faraday::FlatParamsEncoder
          req.params = params.merge(options)
        end
      end
    end

    def post_json(http_url, json)
      post_to_api(http_url, json).body
    end

    def post_to_api(http_url, json)
      perform_request(http_url) do |conn|
        conn.post do |req|
          req.headers['X-Request-Id'] = Thread.current[:request_id] if Thread.current[:request_id]
          req.headers['Accept'] = 'application/json'
          req.headers['Content-Type'] = 'application/json'
          req.body = json
        end
      end
    end

    # Perform an HTTP request against http_url, timing and instrumenting it consistently
    # regardless of whether it succeeds, times out, fails to connect, or 404s
    def perform_request(http_url) # rubocop:disable Metrics/MethodLength
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC, :microsecond)
      conn = create_http_connection(http_url)

      response = yield(conn)
      instrument_response(response, start_time)
      response
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
      instrument_connection_failure(http_url, e, start_time)
      raise e
    rescue Faraday::ResourceNotFound => e
      instrument_service_exception(http_url, e, start_time)
      raise e
    end

    def create_http_connection(http_url) # rubocop:disable Metrics/MethodLength
      Faraday.new(url: http_url) do |config|
        config.options[:timeout] = @connection_timeout
        config.use Faraday::Request::UrlEncoded
        config.use Faraday::FollowRedirects::Middleware

        if instrumenter
          config.request :instrumentation, name: 'requests.data_services_api', instrumenter:
        end
        # Faraday::ResourceNotFound (404) is not transient and is deliberately not retried.
        # Inner middleware exhausts its own budget before the exception reaches the next layer,
        # so stack the more conservative timeout retry inside the more generous connection retry.
        config.request :retry, @connection_failed_retry_options
        config.request :retry, @timeout_retry_options

        config.response :json
        # ! Since responses are processed by the middleware stack in reverse order
        config.response :raise_error
        # ! Passing the logger in last ensures that errors are logged before the exception is raised.
        config.response :logger, @faraday_logger, @faraday_logger_options if @faraday_logger
      end
    end

    def as_http_api(api)
      return api if api.start_with?('http://', 'https://')

      # if the API is a relative path, append to the base URL
      URI.join(@url, api).to_s
    end

    def instrument_response(response, start_time)
      elapsed_time = elapsed_ms(start_time)
      instrumenter&.instrument(
        'response.data_services_api',
        response:,
        duration: elapsed_time
      )
    end

    def instrument_connection_failure(http_url, exception, start_time)
      instrumenter&.instrument(
        'connection_failure.data_services_api',
        exception:,
        path: URI.parse(http_url).path,
        query_string: URI.parse(http_url).query,
        duration: elapsed_ms(start_time),
        status: 503
      )
    end

    def instrument_service_exception(http_url, exception, start_time)
      # ServiceException#status vs Faraday::Error#response_status: this method's caller
      # only ever rescues Faraday::ResourceNotFound, but the status lookup stays duck-typed
      # in case a ServiceException is ever routed through here too
      status = exception.respond_to?(:status) ? exception.status : exception.response_status

      instrumenter&.instrument(
        'service_exception.data_services_api',
        exception:,
        path: URI.parse(http_url).path,
        query_string: URI.parse(http_url).query,
        duration: elapsed_ms(start_time),
        status:
      )
    end

    # Return true if we're currently running in a Rails environment
    def in_rails?
      defined?(Rails)
    end

    # The elapsed time in milliseconds since the given CLOCK_MONOTONIC microsecond timestamp
    def elapsed_ms(start_time)
      (Process.clock_gettime(Process::CLOCK_MONOTONIC, :microsecond) - start_time) / 1000
    end
  end
end
