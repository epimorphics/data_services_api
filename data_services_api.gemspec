# frozen_string_literal: true

require_relative 'lib/data_services_api/version'

Gem::Specification.new do |spec|
  spec.name          = 'data_services_api'
  spec.version       = DataServicesApi::VERSION
  spec.authors       = ['Epimorphics Ltd']
  spec.email         = ['info@epimorphics.com']
  spec.summary       = 'Data Services API'
  spec.description   = 'Ruby wrapper for Epimorphics Data Services API'
  spec.homepage      = 'https://github.com/epimorphics/data_services_api'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.4'

  spec.files         = Dir.glob('lib/**/*', File::FNM_DOTMATCH) + ['LICENSE.txt', 'README.md']
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.extra_rdoc_files = Dir['README.md', 'CHANGELOG.md', 'LICENSE.txt']
  spec.require_paths = ['lib']

  spec.metadata = {
    'bug_tracker_uri' => 'https://github.com/epimorphics/data_services_api/issues',
    'changelog_uri' => 'https://github.com/epimorphics/data_services_api/blob/main/CHANGELOG.md',
    'documentation_uri' => 'https://www.rubydoc.info/gems/data_services_api',
    'homepage_uri' => spec.homepage,
    'rubygems_mfa_required' => 'true'
  }

  spec.add_dependency 'faraday', '~> 2.13', '>= 2.13.0'
  spec.add_dependency 'faraday-follow_redirects', '~> 0.4', '>= 0.4.0'
  spec.add_dependency 'faraday-retry', '~> 2.0', '>= 2.0'
  spec.add_dependency 'json', '~> 2.0'
end
