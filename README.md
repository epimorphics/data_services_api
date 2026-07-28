# Epimorphics Data Services API gem

This gem provides a Ruby API for back-end data services used in the HMLR linked
data applications. Specifically, it allows a simple expression language to be
used to specify queries into an [RDF data
cube](https://www.w3.org/TR/vocab-data-cube/), in which a collection of data
readings, known as _measures_ are organised into a hyper-cube of two or more
_dimensions_.

## Contents

- [History](#history)
- [Usage](#usage)
  - [Quick start](#quick-start)
  - [`Service` configuration options](#service-configuration-options)
- [Developer notes](#developer-notes)
  - [Linting](#linting)
  - [Tests](#tests)
  - [Publishing the gem to the Epimorphics GitHub Package Registry](#publishing-the-gem-to-the-epimorphics-github-package-registry)
  - [Prometheus monitoring](#prometheus-monitoring)

## History

Originally, the expression language used by this gem was interpreted directly by
the [DsAPI](https://github.com/epimorphics/data-API/wiki). DsAPI presented a
RESTful API in which data expressions could be translated systematically into
SPARQL expressions, executed against a remote SPARQL endpoint, and then results
returned to the caller in a compact JSON format.

In 2021, we took the decision to retire the DsAPI codebase, which has not been
actively maintained for some time. In its place, we now expect to use
[Sapi-NT](https://github.com/epimorphics/sapi-nt). Sapi-NT performs a similar
function, in that it provides a RESTful API in which compact queries are
translated into SPARQL expressions, and the results are available in (amongst
other formats) JSON encoding. However, the input to Sapi-NT, in which we
articulate the projection of the underlying hypercube that we require is encoded
as URL parameters in an HTTP GET request. DsAPI, in contrast, expects the input
query to be POSTed as a JSON expression.

To minimise changes to the client applications in which this gem is used, we
have implemented a shim layer that accepts DsAPI expressions and re-codes them
as Sapi-NT URLs. Similarly, differences in the returned JSON results formats are
also ironed out by this shim layer. It is possible to do this because, once the
designs of the applications had settled, the HMLR apps only use a subset of the
expressive power of the DsAPI expression language.

It would be possible to simplify this code further, at the expense of needing to
make changes to the calling application code. At the time, we did not believe
this to be a cost-effective change, and no benefit to end-users (the internals
of the query language are not exposed to end-users). This calculation may be
different in future.

---

## Usage

This gem requires Ruby >= 3.4.

To add this gem as a dependency to another Ruby project, add this line to your
application's Gemfile:

```ruby
source 'https://rubygems.pkg.github.com/epimorphics' do
  gem 'data_services_api'
end
```

_N.B. An API URL needs to be provided by that project for the `Service` class in
order for the gem to work._

### Quick start

```ruby
require 'data_services_api'

service = DataServicesApi::Service.new(url: 'https://example.landregistry.gov.uk')
dataset = service.dataset('ukhpi')

# A query is any object that responds to `terms` (a Hash of DsAPI expression
# terms) and `to_json`
query = Class.new do
  def terms
    { '@and' => [
      { 'ukhpi:refMonth' => { '@ge' => { :@value => '2019-01', :@type => 'http://www.w3.org/2001/XMLSchema#gYearMonth' } } },
      { 'ukhpi:refRegion' => { '@eq' => { :@id => 'http://landregistry.data.gov.uk/id/region/united-kingdom' } } }
    ], '@sort' => [
      { '@down' => 'ukhpi:refMonth' }
    ], '@limit' => 1 }
  end

  def to_json(*_args)
    terms.to_json
  end
end.new

result = dataset.query(query)
```

`dataset.query` translates the DsAPI-style expression into a Sapi-NT URL,
executes it against the configured API, and returns the result re-shaped back
into the legacy DsAPI JSON format.

### `Service` configuration options

`DataServicesApi::Service.new` accepts a config hash with the following keys,
all optional except `url`:

- `url` - the base URL of the Sapi-NT API to query against
- `instrumenter` - an object responding to `instrument(name, payload, &block)`
  (e.g. `ActiveSupport::Notifications`), used to emit the notifications
  described below. Defaults to `ActiveSupport::Notifications` when running
  under Rails, otherwise `nil`. The gem itself never logs anything: consuming
  applications are expected to subscribe to these notifications and log
  whatever they need, in whatever format and at whatever level they choose
- `faraday_logger` - an object responding to the standard `Logger` levels
  (`info`, `warn`, `error`, `debug`). When given, enables Faraday's own
  request/response logging middleware, passing this object to it. Not
  enabled unless explicitly configured
- `faraday_logger_options` - options passed to Faraday's logging middleware
  (`headers`, `bodies`, `errors`, `log_level`), only relevant when
  `faraday_logger` is also given. Merged over the default of
  `headers: false, bodies: false, errors: false, log_level: :debug`, so
  Faraday's request/response one-liners log at `debug` by default, staying
  quiet unless the consuming app turns its own logger's level down
- `connection_failed_retry_options` - a hash of
  [`faraday-retry`](https://github.com/lostisland/faraday-retry) options
  (`max`, `interval`, `interval_randomness`, `backoff_factor`) applied to
  `Faraday::ConnectionFailed` errors (e.g. a colocated service restarting).
  Merged over the default of `max: 4, interval: 0.5, interval_randomness: 0.25,
  backoff_factor: 2`
- `timeout_retry_options` - same shape as above, applied to
  `Faraday::TimeoutError` errors. Merged over the default of `max: 2,
  interval: 0.25, interval_randomness: 0.5, backoff_factor: 2`. Kept more
  conservative than the connection-failure retry budget since retrying an
  overloaded upstream aggressively can make things worse

`Faraday::ResourceNotFound` (404) responses are not retried, since a 404 is
not a transient failure.

---

## Developer notes

### Linting

Rubocop should not report any warnings:

```sh
$ bundle exec rubocop
Inspecting 21 files
.....................

21 files inspected, no offenses detected
```

### Tests

You will need to have started the [HMLR Data
API](https://github.com/epimorphics/lr-data-api) locally. To do so follow the
instructions in the repository's
[README](https://github.com/epimorphics/lr-data-api#run)

Once the API is started you can invoke the tests with the simple command
below:

```sh
bundle exec rake test
```

You can also set the environment variable `API_URL` to point to a running
instance of the HMLR Data API from a non-default port:

```sh
API_URL=http://localhost:8080 bundle exec rake test
```

_N.B If `API_URL` environment variable is not set it will default to
`http://localhost:8888`_

---

### Publishing the gem to the Epimorphics GitHub Package Registry

This gem is published to the Epimorphics section of the GitHub Package
Registry (GPR). Previously we linked directly to the GitHub repo in the
`Gemfile`s of applications consuming this library, but this practice is now
anti-preferred.

The process is:

1. Make the required code changes, and have them reviewed by other members of
   the team
2. Before creating a release, you **must**:
   - Bump `DataServicesApi::VERSION` in
     `lib/data_services_api/version.rb` following semantic version principles
   - Update `CHANGELOG.md`, moving the `Unreleased` section's contents under a
     new heading for the version being released
   - Run `bundle lock --local` (or `bundle install`) to regenerate
     `Gemfile.lock` with the new version and commit the result — the release
     workflow runs `bundle install` in frozen/deployment mode, which fails if
     the lockfile still references the previous gem version
3. Check that the gem builds correctly by running `gem build
   data_services_api.gemspec`
   - The local gem file will be ignored by the `.gitignore` file and not
     included in the recorded code changes in the repository.
4. Push the changes to the `main` branch via a pull request
5. On PR merge, create a GitHub Release (via the UI or `gh release create
   X.Y.Z --repo epimorphics/data_services_api`)

Publishing the GitHub Release triggers the release workflow, which builds the
gem and publishes it to the [Epimorphics GitHub Package
Registry](https://github.com/orgs/epimorphics/packages) automatically — no
local credentials required.

### Prometheus monitoring

This gem integrates with Prometheus monitoring, and supports general-purpose
logging, by emitting the following `ActiveSupport::Notification`s via the
configured `instrumenter`:

- `requests.data_services_api` - raw Faraday request/response timing, emitted
  by Faraday's own instrumentation middleware
- `response.data_services_api` - API response, including the `Faraday::Response`
  object and request duration
- `query_result.data_services_api` - the outcome of a `Service#dataset` query,
  including request `path`, HTTP `method`, response `status`, and
  `returned_rows`
- `connection_failure.data_services_api` - failure to connect to the API,
  with exception detail, `path`, `query_string`, `duration` and `status`
- `service_exception.data_services_api` - failure to process the API
  response, with exception detail, `path`, `query_string`, `duration` and
  `status`

Subscribe to these from the consuming application to log or monitor them, for
example:

```ruby
ActiveSupport::Notifications.subscribe('response.data_services_api') do |*, payload|
  Rails.logger.info(payload.slice(:duration).to_json)
end
```
