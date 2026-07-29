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

### Errors

`Service` raises two kinds of exception, depending on where the failure
happened:

- **Network-level failures** — the request never got a response at all —
  raise Faraday's own `Faraday::TimeoutError` / `Faraday::ConnectionFailed`
  directly (after retries are exhausted). These are left as-is rather than
  wrapped, since they're about the transport, not the API
- **Application-level failures** — the remote API responded, but with an
  error status (any 4xx/5xx) or a body that couldn't be parsed as JSON —
  are always raised as `DataServicesApi::ServiceException`, never as the
  underlying Faraday exception (`Faraday::ResourceNotFound`,
  `Faraday::ClientError`, `Faraday::ServerError`, `Faraday::ParsingError`,
  etc). `ServiceException` exposes `status` (the HTTP status code, where
  available), `service_message` (the underlying error detail), and `source`
  (the URL that was requested), giving consuming applications one stable
  type to rescue for this whole category, regardless of which Faraday
  version or exact status code is behind it

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

- **`requests.data_services_api`** - emitted by Faraday's own instrumentation
  middleware, for every request. **Its payload is not a Hash** like every
  other event below - it's the raw `Faraday::Env` for the request (read
  fields via its own accessors, e.g. `env.method`, `env.url`), so a
  subscriber to this event needs different handling than the rest.
- **`response.data_services_api`** - fires for every response that doesn't
  raise (both GET and POST).
- **`connection_failure.data_services_api`** - a network-level failure
  (timeout or refused connection), after retries are exhausted. The request
  never got a response at all.
- **`service_exception.data_services_api`** - the remote API responded, but
  with an error status (any 4xx/5xx) or an unparseable body. The exception in
  this payload is always a `DataServicesApi::ServiceException` - Faraday's own
  exception types are wrapped before a subscriber ever sees them.
- **`retry.data_services_api`** - fired immediately before each retry attempt
  on a network failure (not for `service_exception`-class failures, which
  aren't retried).

Payload fields, by event (fields are Hash keys except where noted; `-` means
the event doesn't include that field):

| Field | Type | requests<sup>†</sup> | response | connection_failure | service_exception | retry |
|---|---|---|---|---|---|---|
| `response` | `Faraday::Response` | - | ✓ | - | - | - |
| `exception` | see note | - | - | `Faraday::TimeoutError`/`ConnectionFailed` | `ServiceException` | see note |
| `path` | `String` (bare path, no scheme/host/query) | - | -<sup>‡</sup> | ✓ | ✓ | ✓ |
| `query_string` | `String`, nilable<sup>§</sup> | - | -<sup>‡</sup> | ✓ | ✓ | - |
| `method` | `String`, upcased | - | -<sup>‡</sup> | - | - | ✓ |
| `status` | `Integer`, nilable | - | -<sup>‡</sup> | always `503` | nilable<sup>¶</sup> | - |
| `duration` | `Integer`, **milliseconds** | - | ✓ | ✓ | ✓ | - |
| `will_retry_in` | `Float`, **seconds** | - | - | - | - | ✓ |
| `retry_count` | `Integer`, 1-indexed | - | - | - | - | ✓ |
| `returned_rows` | `Integer`, nilable | - | -<sup>‡</sup> | - | - | - |

<sup>†</sup> `requests.data_services_api`'s payload is a `Faraday::Env`, not a
Hash - none of these field names apply; see above.<br>
<sup>‡</sup> derivable from the `response:`/`exception:` object already in
the payload rather than duplicated as a separate field - see the code
examples below.<br>
<sup>§</sup> `nil` for POST requests (which never have query params) and for
GET requests with no params.<br>
<sup>¶</sup> `nil` if Faraday never associated a response with the error
(`Faraday::Error#response_status` returns `nil` in that case - can happen
for some `Faraday::ParsingError`s).

**`duration` (milliseconds) and `will_retry_in` (seconds) use different units
and types** - both describe elapsed/remaining time, but come from different
underlying sources (this gem's own timing vs. `faraday-retry`'s own values
passed straight through) and were never normalized against each other. This
is an inconsistency, not an intentional design choice - don't assume the two
are interchangeable.

**`exception` in `retry.data_services_api`** is normally a raised exception
(`Faraday::TimeoutError`/`ConnectionFailed`), but per `faraday-retry`'s own
design it would be the synthetic `Faraday::RetriableResponse` if a
status-code-based `retry_statuses:` option were ever configured. This gem
doesn't set that option today, so in practice it's always a real exception -
but that's this gem's current configuration, not a structural guarantee.

### Subscribing to hooks in a Rails app

The simplest way to subscribe is a block, registered once in an initializer
(e.g. `config/initializers/data_services_api.rb`):

```ruby
ActiveSupport::Notifications.subscribe('response.data_services_api') do |*, payload|
  Rails.logger.info(duration: payload[:duration], status: payload[:response].status)
end

ActiveSupport::Notifications.subscribe('service_exception.data_services_api') do |*, payload|
  Rails.logger.error(
    message: "API service exception: #{payload[:exception].message}",
    path: payload[:path],
    status: payload[:status]
  )
end
```

For anything beyond a line or two, an `ActiveSupport::Subscriber` is the more
idiomatic Rails pattern — one method per event, matched by name
(`attach_to :data_services_api` routes `response.data_services_api` to a
`#response` method, and so on):

```ruby
# app/subscribers/data_services_api_subscriber.rb
class DataServicesApiSubscriber < ActiveSupport::Subscriber
  attach_to :data_services_api

  def response(event)
    response = event.payload[:response]
    Prometheus::Client.registry.get(:api_status)
                      .increment(labels: { status: response.status.to_s })
    Prometheus::Client.registry.get(:api_response_times)
                      .observe(event.payload[:duration])
  end

  def connection_failure(event)
    exception = event.payload[:exception]
    Prometheus::Client.registry.get(:api_connection_failure).increment
    Rails.logger.error(message: "API connection failure: #{exception.message}", status: 503)
  end

  def service_exception(event)
    exception = event.payload[:exception]
    Prometheus::Client.registry.get(:api_service_exception).increment
    Rails.logger.error(message: "API service exception: #{exception.message}", status: event.payload[:status])
  end

  def retry(event)
    Rails.logger.warn(
      message: "Retrying #{event.payload[:method]} #{event.payload[:path]} " \
                "(attempt #{event.payload[:retry_count]}) in #{event.payload[:will_retry_in]}s",
      exception: event.payload[:exception].class.name
    )
  end
end
```

`attach_to :data_services_api` in the class body (as above) subscribes
immediately when the class loads — no separate initializer call needed.
A subscriber under `app/subscribers/` is autoloaded the first time it's
referenced; since nothing in the app calls
`DataServicesApiSubscriber` directly, eager loading it in
production (Rails does this automatically for `app/` in production) is
what makes sure it's actually loaded, and therefore attached, before any
requests are served. In development, where eager loading is off,
reference the class once from an initializer instead, so it's guaranteed
to load (and attach) at boot rather than on first use:

```ruby
# config/initializers/data_services_api.rb
DataServicesApiSubscriber
```

**Deriving the returned row count** (see the note on `response.data_services_api`
above — it isn't a separate field):

```ruby
def response(event)
  response = event.payload[:response]
  returned_rows = response.body['items']&.size
  # ...
end
```
