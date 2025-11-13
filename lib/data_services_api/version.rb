# frozen_string_literal: true

# :nodoc:
module DataServicesApi
  MAJOR = 1
  MINOR = 6
  PATCH = 1
  SUFFIX = nil
  VERSION = "#{MAJOR}.#{MINOR}.#{PATCH}#{SUFFIX && ".#{SUFFIX}"}".freeze
end
