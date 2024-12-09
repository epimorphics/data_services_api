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
    def get_json(http_url, params, options) # rubocop:disable Metrics/MethodLength
      query_string = params.map { |k, v| "#{k}=#{v}" }.join('&')
      log_message(
        nil,
        0,
        message: "Data Services API request received: #{http_url}",
        status: 200,
        request_url: "#{http_url}?#{query_string}",
        log_type: 'info',
        response_status: 'received'
      )

      response = get_from_api(http_url, 'application/json', params, options)
      parse_json(response.body)
    end

    def get_from_api(http_url, accept_headers, params, options) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      # immediately log the time the request was sent in microseconds
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC, :microsecond)
      conn = set_connection_timeout(create_http_connection(http_url))

      response = conn.get do |req|
        req.headers['X-Request-Id'] = Thread.current[:request_id] if Thread.current[:request_id]
        req.headers['Accept'] = accept_headers
        req.options.params_encoder = Faraday::FlatParamsEncoder
        req.params = params.merge(options)
      end

      # immediately log the response was received
      instrument_response(response, start_time, status: 'received')

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

    def post_to_api(http_url, json) # rubocop:disable Metrics/AbcSize
      # immediately log the time the request was sent in microseconds
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC, :microsecond)
      conn = set_connection_timeout(create_http_connection(http_url))

      response = conn.post do |req|
        req.headers['X-Request-Id'] = Thread.current[:request_id] if Thread.current[:request_id]
        req.headers['Accept'] = 'application/json'
        req.headers['Content-Type'] = 'application/json'
        req.body = json
      end

      # immediately log the response was received
      instrument_response(response, start_time, status: 'received')

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

    def instrument_response(response, start_time, status: 'completed')
      log_message(response, start_time, request_status: status)
      # immediately log the time the response was received in microseconds
      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC, :microsecond)
      # calculate the elapsed time in milliseconds by dividing the difference in time by 1000
      elapsed_time = (end_time - start_time) / 1000
      instrumenter&.instrument(
        'response.api',
        response: response,
        duration: elapsed_time
      )
    end

    def instrument_connection_failure(http_url, exception, start_time)
      # Service Unavailable status code (see https://httpstatuses.com/503)
      log_message(
        nil,
        start_time,
        message: exception.message,
        status: 503,
        request_url: http_url,
        log_type: 'error',
        request_status: 'error'
      )
      instrumenter&.instrument('connection_failure.api', exception)
    end

    def instrument_service_exception(http_url, exception, start_time)
      log_message(
        nil,
        start_time,
        message: exception.message,
        status: exception.status,
        request_url: http_url,
        log_type: 'error',
        request_status: 'error'
      )
      instrumenter&.instrument('service_exception.api', exception)
    end

    # Return true if we're currently running in a Rails environment
    def in_rails?
      defined?(Rails)
    end

    # rubocop:disable Metrics/MethodLength, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity, Metrics/ParameterLists, Metrics/AbcSize, Layout/LineLength
    # Log the message with the appropriate log level
    # @param [Faraday::Response] response - The response object
    # @param [Float] start_time - The time the request was sent
    # @param [String] log_type - The type of log to use (info, warn, error, debug)
    # @param [String] message - The message to log
    # @param [Integer] status - The status code of the response
    # @param [String] request_url - The URL of the request
    # @param [String] request_status - The status of the request (received, processing, completed, error)
    # @return [void]
    def log_message(
      response,
      start_time,
      message = nil,
      status = nil,
      request_url = nil,
      log_type = 'info',
      request_status = 'completed'
    )
      # immediately log the receipt time of the response in miroseconds
      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC, :microsecond)
      # parse out the optional parameters and set defaults
      status ||= response&.status
      request_url ||= response && response.env.url.to_s
      # calculate the elapsed time in milliseconds by dividing the difference in time by 1000
      elapsed_time = (end_time - start_time) / 1000
      # add elapsed time to the message if the api request is completed
      if request_status == 'completed'
        message = "#{request_status.capitalize} Data Services API request, time taken #{format('%.0f ms',
                                                                                               elapsed_time)}"
      else
        message ||= "#{request_status.capitalize} Data Services API request"
      end

      # create a hash of the log fields including the request URL, status, duration, message, and request status
      log_fields = {
        duration: elapsed_time,
        message: message,
        request_status: request_status,
        request_url: request_url,
        status: status
      }

      # Log the API responses at the appropriate level requested
      case log_type
      when 'error'
        logger.error(JSON.generate(log_fields))
      when 'warn'
        logger.warn(JSON.generate(log_fields))
      when 'debug'
        logger.debug(JSON.generate(log_fields))
      else
        logger.info(JSON.generate(log_fields))
      end
      logger.flush if logger.respond_to?(:flush)
    end
    # rubocop:enable Metrics/MethodLength, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity, Metrics/ParameterLists, Metrics/AbcSize, Layout/LineLength
  end
end
