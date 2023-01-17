# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'data_services_api/version'

Gem::Specification.new do |spec|
  spec.name          = 'data_services_api'
  spec.version       = DataServicesApi::VERSION
  spec.authors       = ['Epimorphics Ltd']
  spec.email         = ['info@epimorphics.com']
  spec.summary       = 'Data Services API'
  spec.description   = 'Ruby wrapper for Epimorphics Data Services API'
  spec.homepage      = 'https://github.com/epimorphics/data-API-ruby'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 2.6'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/}) # rubocop:disable Gemspec/DeprecatedAttributeAssignment
  spec.require_paths = ['lib']

  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.add_runtime_dependency 'faraday_middleware', '~> 1.2.0'
  spec.add_runtime_dependency 'json', '~> 2.6.1'
  spec.add_runtime_dependency 'yajl-ruby', '~> 1.4.1'

  spec.add_development_dependency 'bundler', '~> 2.4'
  spec.add_development_dependency 'byebug', '~> 11.1.3'
  spec.add_development_dependency 'excon', '~> 0.90.0'
  spec.add_development_dependency 'json_expressions', '~> 0.9.0'
  spec.add_development_dependency 'minitest', '~> 5.15.0'
  spec.add_development_dependency 'minitest-rg', '~> 5.2.0'
  spec.add_development_dependency 'minitest-vcr', '~> 1.4.0'
  spec.add_development_dependency 'mocha', '~> 1.13.0'
  spec.add_development_dependency 'rake', '~> 13.0.6'
  spec.add_development_dependency 'rubocop', '~> 1.25.0'
  spec.add_development_dependency 'webmock', '~> 3.14.0'
end
