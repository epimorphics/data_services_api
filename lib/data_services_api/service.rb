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
        req.headers['X-Request-ID'] = Thread.current[:request_id] if Thread.current[:request_id]
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
        req.headers['X-Request-ID'] = Thread.current[:request_id] if Thread.current[:request_id]
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
        response_body = JSON.parse(response.body, symbolize_names: true)
        response_message = response_body[:message]
        response_error = response_body[:error]
        msg = "#{response_error}: #{response_message}"

        raise ServiceException.new(msg, response.status, http_url, response.body)
      end

      true
    end

    def as_http_api(api)
      api.start_with?('http:') ? api : "#{url}#{api}"
    end

    def report_json_failure(json)
      msg = "JSON result was not parsed correctly: #{json.slice(0, 1000)}"

      if in_rails?
        # msg = 'JSON result was not parsed correctly (no temp file saved)'
        logger.error(msg)
      end

      throw msg
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
      # Service Unavailable status code (see https://httpstatuses.com/503)
      log_api_response(
        nil,
        start_time,
        message: exception.message,
        status: 503,
        request_url: http_url,
        log_type: 'error'
      )
      instrumenter&.instrument('connection_failure.api', exception)
    end

    def instrument_service_exception(http_url, exception, start_time)
      log_api_response(
        nil,
        start_time,
        message: exception.message,
        status: exception.status,
        request_url: http_url,
        log_type: 'error'
      )
      instrumenter&.instrument('service_exception.api', exception)
    end

    # Return true if we're currently running in a Rails environment
    def in_rails?
      defined?(Rails)
    end

    # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/ParameterLists
    # Log the API response
    # @param [Faraday::Response] response - The response object
    # @param [Float] start_time - The time the request was sent
    # @param [String] log_type - The type of log to use (info, warn, error, debug)
    # @param [String] message - The message to log
    # @param [Integer] status - The status code of the response
    # @param [String] request_url - The URL of the request
    # @return [void]
    def log_api_response(
      response,
      start_time,
      message = 'completed',
      status = nil,
      request_url = nil,
      log_type = 'info'
    )
      # immediately log the receipt time of the response
      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC, :microsecond)
      # parse out the optional parameters and set defaults
      status ||= response && response.status
      request_url ||= response && response.env.url.to_s
      # calculate the elapsed time
      elapsed_time = end_time - start_time
      # add the request url and elapsed time to the message if it's the default message
      if message == 'Completed'
        message = "#{message} #{request_url}, time taken #{format('%.0f μs',
                                                                  elapsed_time)}"
      end

      case log_type
      when 'error'
        log_error(
          request_url: request_url,
          status: status,
          duration: elapsed_time,
          message: message
        )
      when 'warn'
        log_warn(
          request_url: request_url,
          status: status,
          duration: elapsed_time,
          message: message
        )
      when 'debug'
        log_debug(
          request_url: request_url,
          status: status,
          duration: elapsed_time,
          message: message
        )
      else
        log_info(
          request_url: request_url,
          status: status,
          duration: elapsed_time,
          message: message
        )
      end
    end
    # rubocop:enable Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/ParameterLists

    # These helper methods log the API responses at the appropriate level requested
    def log_info(info)
      logger.info(info)
    end

    def log_warn(warn)
      logger.warn(warn)
    end

    def log_error(error)
      logger.error(error)
    end

    def log_debug(debug)
      logger.debug(debug)
    end
  end
end
