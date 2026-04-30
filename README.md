# Epimorphics Data Services API gem

This gem provides a Ruby API for back-end data services used in the HMLR linked
data applications. Specifically, it allows a simple expression language to be
used to specify queries into an [RDF data
cube](https://www.w3.org/TR/vocab-data-cube/), in which a collection of data
readings, known as _measures_ are organised into a hyper-cube of two or more
_dimensions_.

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

To add this gem as a dependency to another Ruby project, add this line to your
application's Gemfile:

```ruby
source 'https://rubygems.pkg.github.com/epimorphics' do
  gem 'data_services_api'
end
```

_N.B. An API URL needs to be provided by that project for the `Service` class in
order for the gem to work._

---

## Contributing

For setup instructions, available `make` targets, running tests, linting, and
publishing releases, see [CONTRIBUTING.md](CONTRIBUTING.md).

---

### Prometheus monitoring

This gem integrates with Prometheus monitoring by emitting the following
`ActiveSupport::Notification`s:

- `response.api` - API response, including status code and duration
- `connection_failure.api` - failure to connect to the API, with exception
  detail
- `service_exception.api` - failure to process the API response
