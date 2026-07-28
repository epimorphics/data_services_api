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

      data_api = "#{@url}/landregistry/id/#{name}"
      endpoint = {
        'data-api' => data_api,
        'dataset' => name,
        'structure-api' => "#{data_api}/structure",
        'describe-api' => "#{data_api}/describe"
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
        query_string: response.env.url.query,
        method: response.env.method.upcase,
        status: response.status,
        returned_rows:
      )

      response_body
    end

    def get_from_api(http_url, accept_headers, params, options)
      query_params = params.merge(options)

      perform_request(http_url, query_params) do |conn|
        conn.get do |req|
          req.headers['X-Request-Id'] = Thread.current[:request_id] if Thread.current[:request_id]
          req.headers['Accept'] = accept_headers
          req.options.params_encoder = Faraday::FlatParamsEncoder
          req.params = query_params
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
    # regardless of whether it succeeds, times out, fails to connect, or the remote API
    # returns an error status or unparseable body. query_params, when given, is only used
    # to report the query string on connection/service failures (a successful response
    # reports its own resolved query string from the Faraday response itself)
    def perform_request(http_url, query_params = nil) # rubocop:disable Metrics/MethodLength
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC, :microsecond)
      conn = create_http_connection(http_url)

      response = yield(conn)
      instrument_response(response, start_time)
      response
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
      instrument_connection_failure(http_url, query_params, e, start_time)
      raise e
    rescue Faraday::Error => e
      service_exception = ServiceException.new(
        e.message, e.response_status, http_url, e.response_body
      )
      instrument_service_exception(http_url, query_params, service_exception, start_time)
      raise service_exception
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
        config.request :retry, with_retry_instrumentation(@connection_failed_retry_options)
        config.request :retry, with_retry_instrumentation(@timeout_retry_options)

        config.response :json
        # ! Since responses are processed by the middleware stack in reverse order
        config.response :raise_error
        # ! Passing the logger in last ensures that errors are logged before the exception is raised.
        config.response :logger, @faraday_logger, @faraday_logger_options if @faraday_logger
      end
    end

    # Add a retry_block to the given faraday-retry options that fires a
    # retry.data_services_api notification before each retry attempt, preserving any
    # retry_block the caller already configured
    def with_retry_instrumentation(options)
      return options unless instrumenter

      original_retry_block = options[:retry_block]

      options.merge(
        retry_block: lambda do |env:, options:, retry_count:, exception:, will_retry_in:|
          original_retry_block&.call(env:, options:, retry_count:, exception:, will_retry_in:)
          instrument_retry(env, retry_count, exception, will_retry_in)
        end
      )
    end

    def instrument_retry(env, retry_count, exception, will_retry_in)
      instrumenter.instrument(
        'retry.data_services_api',
        path: env.url.path,
        method: env.method.to_s.upcase,
        retry_count: retry_count + 1,
        exception:,
        will_retry_in:
      )
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

    def instrument_connection_failure(http_url, query_params, exception, start_time)
      instrumenter&.instrument(
        'connection_failure.data_services_api',
        exception:,
        path: URI.parse(http_url).path,
        query_string: query_params && URI.encode_www_form(query_params),
        duration: elapsed_ms(start_time),
        status: 503
      )
    end

    # exception is always a ServiceException here: perform_request wraps every
    # Faraday::Error (bad status, unparseable body, etc) into one before raising
    def instrument_service_exception(http_url, query_params, exception, start_time)
      instrumenter&.instrument(
        'service_exception.data_services_api',
        exception:,
        path: URI.parse(http_url).path,
        query_string: query_params && URI.encode_www_form(query_params),
        duration: elapsed_ms(start_time),
        status: exception.status
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
