# Epimorphics Data Services API gem

This gem provides a Ruby API for back-end data services used in the HMLR
linked data applications. Specifically, it allows a simple expression language
to be used to specify queries into an [RDF data cube](https://www.w3.org/TR/vocab-data-cube/),
in which a collection of data readings, known as _measures_ are organised into a
hyper-cube of two or more _dimensions_.

## History

Originally, the expression language used by this gem was interpreted directly by
the [DsAPI](https://github.com/epimorphics/data-API/wiki). DsAPI presented a RESTful
API in which data expressions could be translated systematically into SPARQL
expressions, executed against a remote SPARQL endpoint, and then results
returned to the caller in a compact JSON format.

In 2021, we took the decision to retire the DsAPI codebase, which has not been
actively maintained for some time. In its place, we now expect to use
[Sapi-NT](https://github.com/epimorphics/sapi-nt). Sapi-NT performs a similar
function, in that it provides a RESTful API in which compact queries are translated
into SPARQL expressions, and the results are available in (amongst other formats)
JSON encoding. However, the input to Sapi-NT, in which we articulate the projection
of the underlying hypercube that we require is encoded as URL parameters in an
HTTP GET request. DsAPI, in contrast, expects the input query to be POSTed as a
JSON expression.

To minimise changes to the client applications in which this gem is used, we have
implemented a shim layer that accepts DsAPI expressions and re-codes them as Sapi-NT
URLs. Similarly, differences in the returned JSON results formats are also ironed
out by this shim layer. It is possible to do this because, once the designs of the
applications had settled, the HMLR apps only use a subset of the expressive power
of the DsAPI expression language.

It would be possible to simplify this code further, at the expense of needing to
make changes to the calling application code. At the time, we did not believe this
to be a cost-effective change, and no benefit to end-users (the internals of the
query language are not exposed to end-users). This calculation may be different in
future.

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

## Developer notes

### Linting

Rubocop should not report any warnings:

```sh
$ rubocop
Inspecting 21 files
.....................

21 files inspected, no offenses detected
```

### Tests

You will need to have started the [HMLR Data API](https://github.com/epimorphics/lr-data-api)
locally. To do so follow the instructions in the repository's [README](https://github.com/epimorphics/lr-data-api#run)

Once the API is started you can invoke the tests with the simple command below[^1]:

```sh
rake test
```

You can also set the environment variable `API_URL` to point to a running
instance of the HMLR Data API from a non-default port:

```sh
API_URL=http://localhost:8080 rake test
```

_N.B If `API_URL` environment variable is not set it will default to `http://localhost:8888`_

---

### Publishing the gem to the GitHub Package Registry

This gem is now published to the Epimorphics section of the GitHub Package
Registry (GPR). Previously we linked directly to the GitHub repo in the
`Gemfile`s of applications consuming this library, but this practice is now
anti-preferred.

Note that in order to publish to the Epimorphics section of the GPR, you'll
need a GitHub personal access token (PAT). There are [instructions on the Epimorphics
wiki](https://github.com/epimorphics/internal/wiki/Ansible-CICD#creating-a-pat-for-gpr-access)
for creating a new PAT if you don't have one. Once created, you can use the
same PAT in multiple projects, you don't need to create a new one each time.

At present, publishing is a manual step for Gem maintainers. The process is:

1. Make the required code changes, and have them reviewed by other members of
   the team
2. Update `CHANGELOG.md` with the changes. Update
   `lib/data_services_api/version.rb` following semantic version principles
3. Check that the gem builds correctly: `make gem`
4. Publish the new gem to GPR: `make publish`
5. Check on the [GitHub Package
   Registry](https://github.com/orgs/epimorphics/packages?repo_name=data_services_api)
   to see that the new gem has been published.

### Prometheus monitoring

This gem integrates with Prometheus monitoring by emitting the following
`ActiveSupport::Notificaion`s:

- `response.api` - API response, including status code and duration
- `connection_failure.api` - failure to connect to the API, with exception detail
- `service_exception.api` - failure to process the API response

[^1]: You may need to preface the `rake test` command with `bundle exec` if you
      are using a Ruby version manager such as `rbenv` or `rvm`.
