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
      # create a well formatted query string from the params hash to be used in the logging
      query_string = params.map { |k, v| "#{k}=#{v}" }.join('&')
      # parse out the origin from the URL, this is the host but including protocol and port
      origin = http_url.split(URI.parse(http_url).path).first
      # initiate the message to be logged
      logged_fields = {
        message: generate_service_message({
                                            msg: "Calling API: #{origin}",
                                            timer: nil
                                          }),
        path: URI.parse(http_url).path,
        query_string:,
        request_status: 'processing'
      }

      unless logged_fields[:query_string].nil? || logged_fields[:query_string].empty?
        logged_fields[:path] += "?#{logged_fields[:query_string]}"
      end

      log_message(logged_fields)

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC, :microsecond)
      # make the request to the API and get the response immediately
      response = get_from_api(http_url, 'application/json', params, options)
      # next, calculate the elapsed time in milliseconds by dividing the difference in time by 1000
      elapsed_time = (Process.clock_gettime(Process::CLOCK_MONOTONIC, :microsecond) - start_time) / 1000 # rubocop:disable Layout/LineLength
      # now parse the response
      response_body = parse_json(response.body)
      # log the number of rows returned
      returned_rows = response_body['items'] ? response_body['items'].size : 0
      # log the response and status code
      logged_fields[:message] = generate_service_message(
        {
          msg: "API returned #{returned_rows} #{returned_rows == 1 ? 'row' : 'rows'}",
          timer: elapsed_time
        }
      )

      logged_fields[:method] = response.env.method.upcase
      logged_fields[:returned_rows] = returned_rows if returned_rows.positive?
      logged_fields[:request_status] = 'processing'
      logged_fields[:request_time] = elapsed_time
      logged_fields[:status] = response.status

      log_message(logged_fields)
      response_body
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
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
      instrument_connection_failure(http_url, e, start_time)
      raise e
    rescue Faraday::ResourceNotFound, ServiceException => e
      instrument_service_exception(http_url, e, start_time)
      raise e
    end

    # Parse the given JSON string into a data structure. Throws an exception if
    # parsing fails
    def parse_json(json) # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      result = nil
      jsonified = json.is_a?(String) ? json : json.to_json
      json_hash = parser.parse(jsonified) do |json_chunk|
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

    def create_http_connection(http_url, auth = false) # rubocop:disable Metrics/MethodLength
      retry_options = {
        max: 2,
        interval: 0.05,
        interval_randomness: 0.5,
        backoff_factor: 2,
        exceptions: [Faraday::TimeoutError, Faraday::ConnectionFailed, Faraday::ResourceNotFound]
      }

      Faraday.new(url: http_url) do |config|
        config.use Faraday::Request::UrlEncoded
        config.use Faraday::FollowRedirects::Middleware

        config.request :authorization, :basic, api_user, api_pw if auth
        # instrument the request to log the time it takes to complete but only if we're in a Rails environment
        config.request :instrumentation, name: 'requests.api' if in_rails?
        config.request :retry, retry_options
        with_logger_in_rails(config)

        config.response :json
        config.response :raise_error
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
      return api if api.start_with?('http://', 'https://')

      # if the API is a relative path, append to the base URL
      URI::HTTP.build(host: @url, path: api).to_s
    end

    def report_json_failure(json)
      msg = "JSON result was not parsed correctly: #{json.to_s.slice(0, 1000)}"

      if in_rails?
        # msg = 'JSON result was not parsed correctly (no temp file saved)'
        logger.error(msg)
      end

      raise ServiceException.new(msg, 500, nil, json)
    end

    def instrument_response(response, start_time, _request_status)
      # immediately log the time the response was received in microseconds
      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC, :microsecond)
      # calculate the elapsed time in milliseconds by dividing the difference in time by 1000
      elapsed_time = (end_time - start_time) / 1000
      instrumenter&.instrument(
        'response.api',
        response:,
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
          message: exception.message.to_s,
          path: URI.parse(http_url).path,
          query_string: URI.parse(http_url).query,
          start_time: start_time || 0,
          request_status: 'error',
          request_time: elapsed_time,
          status: 503
        },
        'error'
      )

      instrumenter&.instrument('connection_failure.api', exception:)
    end

    def instrument_service_exception(http_url, exception, start_time) # rubocop:disable Metrics/MethodLength
      # immediately log the time the response was received in microseconds
      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC, :microsecond)
      # calculate the elapsed time in milliseconds by dividing the difference in time by 1000
      elapsed_time = (end_time - start_time) / 1000

      # log the exception message and status code but only if we're in a Rails environment
      in_rails? && log_message(
        {
          message: exception.message.to_s,
          path: URI.parse(http_url).path,
          query_string: URI.parse(http_url).query,
          start_time: start_time || 0,
          request_status: 'error',
          request_time: elapsed_time,
          status: exception.status || RACK::Exception::HTTP_STATUS_CODES[exception]
        },
        'error'
      )

      instrumenter&.instrument('service_exception.api', exception:)
    end

    # Return true if we're currently running in a Rails environment
    def in_rails?
      defined?(Rails)
    end

    def with_logger_in_rails(config)
      return config.response :logger unless in_rails?

      level = Rails.env.production? ? :info : :debug

      config.response :logger, Rails.logger, {
        headers: true,
        bodies: false,
        errors: true,
        log_level: level.to_sym
      }
    end

    # rubocop:disable Metrics/MethodLength, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity, Metrics/AbcSize
    # Log the provided properties with the appropriate log level
    # @param [Hash] log_fields - The fields to log
    # @param [String] log_fields.message - The message to log
    # @param [Faraday::Response] log_fields.response - The response object
    # @param [String] log_fields.path - The URL of the request with query string
    # @param [String] log_fields.query_string - The query string of the request
    # @param [String] log_fields.method - The HTTP method of the request
    # @param [String] log_fields.request_status - The status of the request (received, processing, completed, error)
    # @param [Float] log_fields.request_time - The time it took to process the request
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
      log_fields[:message] ||= log_fields[:response]&.body.to_s
      log_fields[:method]
      log_fields[:request_time] ||= duration
      log_fields[:request_status] ||= 'completed' if log_fields[:status] == 200
      log_fields[:start_time] = nil
      log_fields[:status]

      if log_fields[:request_time]
        seconds, milliseconds = log_fields[:request_time].divmod(1000)
        log_fields[:request_time] = format('%.0f.%03d', seconds, milliseconds) # rubocop:disable Style/FormatStringToken
      end

      if log_fields[:query_string]
        log_fields[:path] += "?#{log_fields[:query_string]}" unless log_fields[:path].to_s.include?('?') # rubocop:disable Layout/LineLength
        log_fields[:query_string] = nil
      end
      # Clear out nil values from the log fields, sort the fields and convert to a hash
      logs = log_fields.compact.sort.to_h

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
    # @param [Float] [timer] - The time it took to process the request
    # @return [String] - The formatted message
    def generate_service_message(fields)
      raise ServiceException.new('Message is required', 400) unless fields[:msg]

      msg = fields[:msg]
      timer = fields[:timer] || 0
      msg += ", time taken: #{format('%.0f ms', timer)}" if timer.positive?
      msg
    end
  end
end
