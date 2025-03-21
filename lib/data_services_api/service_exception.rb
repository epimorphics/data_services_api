# frozen_string_literal: true

# Capture exceptions when talking to remote services

module DataServicesApi
  # A sub-type of RuntimeError for problems that arise when interacting with the
  # DS API
  class ServiceException < RuntimeError
    attr_reader :status, :source, :service_message

    def initialize(msg, status, source = nil, service_message = nil)
      super(msg)

      @status = status
      @source = source
      @service_msg = service_message
    end
  end
end
