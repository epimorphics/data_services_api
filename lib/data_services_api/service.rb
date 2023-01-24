# frozen_string_literal: true

module DataServicesApi
  # Denotes the encapsulated DataServicesAPI service
  class Service # rubocop:disable Metrics/ClassLength
    attr_reader :instrumenter, :logger, :parser, :url

    def initialize(config = {})
      @instrumenter = config[:instrumenter] || (in_rails? && ActiveSupport::Notifications)
      @logger = config[:logger] || (in_rails? && Rails.logger)
      @parser = Yajl::Parser.new
      @url = config[:url]
    end

    def datasets
      api_get_json('/dataset').map { |json| Dataset.new(json, self) }
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
    def get_json(http_url, params, options)
      response = get_from_api(http_url, 'application/json', params, options)
      parse_json(response.body)
    end

    def get_from_api(http_url, accept_headers, params, options) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC, :microsecond)
      conn = set_connection_timeout(create_http_connection(http_url))

      response = conn.get do |req|
        req.headers['Accept'] = accept_headers
        req.options.params_encoder = Faraday::FlatParamsEncoder
        req.params = params.merge(options)
      end

      instrument_response(response, start_time)

      ok?(response, http_url) && response
    rescue ServiceException => e
      instrument_service_exception(http_url, e, start_time)
      throw e
    rescue Faraday::ConnectionFailed => e
      instrument_connection_failure(http_url, e, start_time)
      throw e
    end

    # Parse the given JSON string into a data structure. Throws an exception if
    # parsing fails
    def parse_json(json) # rubocop:disable Metrics/MethodLength
      result = nil

      json_hash = parser.parse(StringIO.new(json)) do |json_chunk|
        if result
          result = [result] unless result.is_a?(Array)
          result << json_chunk
        else
          result = json_chunk
        end
      end

      report_json_failure(json) unless result || json_hash
      result || json_hash
    end

    def post_json(http_url, json)
      response = post_to_api(http_url, json)
      parse_json(response.body)
    end

    def post_to_api(http_url, json)
      conn = set_connection_timeout(create_http_connection(http_url))

      response = conn.post do |req|
        req.headers['Accept'] = 'application/json'
        req.headers['Content-Type'] = 'application/json'
        req.body = json
      end

      ok?(response, http_url) && response
    end

    def create_http_connection(http_url)
      Faraday.new(url: http_url) do |faraday|
        faraday.request(:url_encoded)
        faraday.use(FaradayMiddleware::FollowRedirects)

        # setting the adapter must be the final step, otherwise get a warning from Faraday
        faraday.adapter(:net_http)
      end
    end

    def set_connection_timeout(conn) # rubocop:disable Naming/AccessorMethodName
      conn.options[:timeout] = 600
      conn
    end

    def ok?(response, http_url)
      unless (200..207).cover?(response.status)
        msg = "Failed to read from #{http_url}: #{response.status.inspect}"
        raise ServiceException.new(msg, response.status, http_url, response.body)
      end

      true
    end

    def as_http_api(api)
      api.start_with?('http:') ? api : "#{url}#{api}"
    end

    def report_json_failure(json)
      if in_rails?
        msg = 'JSON result was not parsed correctly (no temp file saved)'
        Rails.logger.info(msg)
        throw msg
      else
        throw "JSON result was not parsed correctly: #{json.slice(0, 1000)}"
      end
    end

    def instrument_response(response, start_time)
      log_api_response(response, start_time)
      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC, :microsecond)
      elapsed_time = end_time - start_time
      instrumenter&.instrument(
        'response.api',
        response: response,
        duration: elapsed_time
      )
    end

    def instrument_connection_failure(http_url, exception, start_time)
      exception_status = 'connection_failure.api'
      log_api_response(
        nil,
        start_time,
        message: exception.message,
        status: exception_status,
        url: http_url
      )
      instrumenter&.instrument(exception_status, exception)
    end

    def instrument_service_exception(http_url, exception, start_time)
      exception_status = 'service_exception.api'
      log_api_response(
        nil,
        start_time,
        message: exception.message,
        status: exception_status,
        url: http_url
      )
      instrumenter&.instrument(exception_status, exception)
    end

    # Return true if we're currently running in a Rails environment
    def in_rails?
      defined?(Rails)
    end

    def log_api_response(response, start_time, url: nil, status: nil, message: 'GET from API')
      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC, :microsecond)
      elapsed_time = end_time - start_time
      logger.info(
        url: response ? response.env[:url].to_s : url,
        status: status || response.status,
        duration: elapsed_time,
        message: message
      )
    end
  end
end
