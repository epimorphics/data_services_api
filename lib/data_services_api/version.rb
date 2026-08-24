# frozen_string_literal: true

# :nodoc:
module DataServicesApi
  MAJOR = 2
  MINOR = 0
  PATCH = 0
  SUFFIX = 'prerelease'
  VERSION = "#{MAJOR}.#{MINOR}.#{PATCH}#{SUFFIX && ".#{SUFFIX}"}".freeze
end
