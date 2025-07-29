# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'simplecov'
SimpleCov.start 'test_frameworks' do
  enable_coverage :branch
end

require 'yajl'
require 'minitest'
require 'minitest/autorun'
require 'minitest/rg'
require 'json_expressions/minitest'

require 'bundler'
Bundler.require(:default, :development, :test)

require 'faraday'
require 'faraday/encoding'
require 'faraday/follow_redirects'
require 'faraday/retry'

require 'byebug'
require 'mocha/minitest'

VCR.configure do |c|
  c.cassette_library_dir = 'fixtures/vcr_cassettes'
  c.hook_into :webmock
end
