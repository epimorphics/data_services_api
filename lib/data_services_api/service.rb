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
    def get_json(http_url, params, options) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC, :microsecond)
      # make the request to the API and get the response immediately
      response = get_from_api(http_url, 'application/json', params, options)
      # next, calculate the elapsed time in milliseconds by dividing the difference in time by 1000
      elapsed_time = (Process.clock_gettime(Process::CLOCK_MONOTONIC, :microsecond) - start_time) / 1000 # rubocop:disable Layout/LineLength
      # now parse the query string from the parameters
      query_string = params.map { |k, v| "#{k}=#{v}" }.join('&')

      logged_fields = {
        message: generate_service_message({
                                            msg: 'Processing request',
                                            source: URI.parse(http_url).path.split('/').last,
                                            timer: elapsed_time
                                          }),
        path: URI.parse(http_url).path,
        query_string: query_string,
        request_status: 'processing',
        request_time: elapsed_time,
        status: response.status || 200,
      }

      log_message(logged_fields, 'info')
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
      instrument_response(response, start_time, 'received')

      ok?(response, http_url) && response
    rescue Faraday::ConnectionFailed => e
      instrument_connection_failure(http_url, e, start_time)
      raise e
    rescue ServiceException => e
      instrument_service_exception(http_url, e, start_time)
      raise e
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
      instrument_response(response, start_time, 'received')

      ok?(response, http_url) && response
    end

    def create_http_connection(http_url, auth = false)
      Faraday.new(url: http_url) do |faraday|
        faraday.use Faraday::Request::UrlEncoded
        faraday.use Faraday::Request::Retry
        faraday.use FaradayMiddleware::FollowRedirects

        # instrument the request to log the time it takes to complete but only if we're in a Rails environment
        faraday.request :instrumentation, name: 'requests.api' if in_rails?

        # set the basic auth if required
        faraday.basic_auth(api_user, api_pw) if auth

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
      api.start_with?('http') ? api : "#{url}#{api}"
    end

    def report_json_failure(json)
      msg = "JSON result was not parsed correctly: #{json.slice(0, 1000)}"

      if in_rails?
        # msg = 'JSON result was not parsed correctly (no temp file saved)'
        logger.error(msg)
      end

      throw msg
    end

    def instrument_response(response, start_time, _request_status)
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

    def instrument_connection_failure(http_url, exception, start_time) # rubocop:disable Metrics/MethodLength
      # immediately log the time the response was received in microseconds
      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC, :microsecond)
      # calculate the elapsed time in milliseconds by dividing the difference in time by 1000
      elapsed_time = (end_time - start_time) / 1000
      # Service Unavailable status code (see https://httpstatuses.com/503)
      # log the exception message and status code but only if we're in a Rails environment
      in_rails? && log_message(
        {
          message: exception.message,
          path: URI.parse(http_url).path,
          query_string: URI.parse(http_url).query,
          start_time: start_time || 0,
          request_status: 'error',
          request_time: elapsed_time,
          status: 503
        },
        'error'
      )

      instrumenter&.instrument('connection_failure.api', exception: exception)
    end

    def instrument_service_exception(http_url, exception, start_time) # rubocop:disable Metrics/MethodLength
      # immediately log the time the response was received in microseconds
      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC, :microsecond)
      # calculate the elapsed time in milliseconds by dividing the difference in time by 1000
      elapsed_time = (end_time - start_time) / 1000

      # log the exception message and status code but only if we're in a Rails environment
      in_rails? && log_message(
        {
          message: exception.message,
          path: URI.parse(http_url).path,
          query_string: URI.parse(http_url).query,
          start_time: start_time || 0,
          request_status: 'error',
          request_time: elapsed_time,
          status: exception.status || RACK::Exception::HTTP_STATUS_CODES[exception]
        },
        'error'
      )

      instrumenter&.instrument('service_exception.api', exception: exception)
    end

    # Return true if we're currently running in a Rails environment
    def in_rails?
      defined?(Rails)
    end

    # rubocop:disable Metrics/MethodLength, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity, Metrics/AbcSize
    # Log the provided properties with the appropriate log level
    # @param [Hash] log_fields - The fields to log
    # @param [String] log_fields.message - The message to log
    # @param [Faraday::Response] log_fields.response - The response object
    # @param [String] log_fields.request_url - The URL of the request
    # @param [String] log_fields.request_status - The status of the request (received, processing, completed, error)
    # @param [Float] log_fields.start_time - The time the request was sent
    # @param [Integer] log_fields.status - The status code of the response
    # @param [String] log_type - The type of log to use (info, warn, error, debug)
    # @return [void]
    def log_message(log_fields, log_type = 'info')
      puts "\n" if in_rails? && Rails.env.development? && Rails.logger.debug? && log_fields.present?
      # immediately log the time the initial response was received in microseconds
      start_time = log_fields[:start_time] if log_fields[:start_time]
      # immediately log the receipt time of the response in miroseconds
      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC, :microsecond)
      # calculate the elapsed time in milliseconds by dividing the difference in time by 1000
      duration = (end_time - start_time) / 1000 if start_time
      # parse out the optional parameters and set defaults
      log_fields[:message] ||= log_fields[:response]&.body
      log_fields[:request_time] ||= duration
      log_fields[:request_status] ||= 'completed' if log_fields[:status] == 200
      log_fields[:start_time] = nil
      log_fields[:status] ||= 200

      # Clear out nil values from the log fields
      logs = log_fields.compact
      # Log the API responses at the appropriate level requested
      case log_type
      when 'error'
        logger.error(JSON.generate(logs))
      when 'warn'
        logger.warn(JSON.generate(logs))
      when 'debug'
        logger.debug(JSON.generate(logs))
      else
        logger.info(JSON.generate(logs))
      end
      logger.flush if logger.respond_to?(:flush)
    end
    # rubocop:enable Metrics/MethodLength, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity, Metrics/AbcSize

    # Construct the message based on the properties received and return the formatted message
    # @param [String] msg - The initial message to log
    # @param [String] [source] - The source of the request
    # @param [Float] [timer] - The time it took to process the request
    # @param [String] [path] - The path of the request
    # @param [String] [query_string] - The query string of the request
    # @return [String] - The formatted message
    def generate_service_message(fields)
      raise ServiceException.new('Message is required', 400) unless fields[:msg]

      msg = fields[:msg]
      source = fields[:source]
      timer = fields[:timer]
      # TODO: Agree on the format and fields to be included in the log message
      # msg += " for #{path}" if in_rails? && fields[:path].present?
      # msg += "?#{query_string}" if in_rails? && fields[:query_string].present?
      msg += " for the #{source.upcase} service" if in_rails? && source.present?
      msg += ", time taken: #{format('%.0f ms', timer)}" if timer.positive?
      msg
    end
  end
end
