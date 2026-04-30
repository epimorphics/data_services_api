# frozen_string_literal: true

source 'https://rubygems.org'

# Specify the gem's runtime dependencies in data_services_api.gemspec
gemspec

# Development dependencies are mirrored here to make them "explicit" for bundler.
# This allows `bundle outdated --only-explicit` to check these dependencies,
# which would otherwise be treated as sub-dependencies from the gemspec.
group :maintenance do
  gem 'faraday', '~> 2.13', '>= 2.13.0'
  gem 'faraday-encoding', '~> 0.0', '>= 0.0.6'
  gem 'faraday-follow_redirects', '~> 0.4', '>= 0.4.0'
  gem 'faraday-retry', '~> 2.0', '>= 2.0'
  gem 'json', '~> 2.0'
  gem 'yajl-ruby', '~> 1.4'
end

# Add development dependencies here though as they are not required to run the gem
group :development, :test do
  gem 'bundler'
  gem 'byebug', platforms: %i[mri windows], require: false
  gem 'excon'
  gem 'json_expressions'
  gem 'minitest'
  gem 'minitest-rg'
  gem 'minitest-vcr'
  gem 'mocha'
  gem 'mutex_m'
  gem 'ostruct'
  gem 'rake'
  gem 'rubocop'
  gem 'simplecov', require: false
  gem 'webmock'
end

group :development do
  gem 'foreman'
end
