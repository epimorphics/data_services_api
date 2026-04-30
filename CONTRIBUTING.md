# Contributing to data-services-api

This guide covers development workflow for the data-services-api gem.

## Getting Started

After cloning the repository:

### Install Dependencies

```sh
make assets
```

This installs all required gems via Bundler.

### GitHub Package Registry Authentication

This gem is published to the Epimorphics GitHub Package Registry. This allows us
to publish and use Rubygems that we create in our own apps without publishing
via the public `rubygems.org` or wiring in direct references to GitHub repos in
our `Gemfile`s.

Access to the GitHub package registry is authorised via a _personal access
token_ (PAT). There are [instructions on the Epimorphics wiki](https://github.com/epimorphics/internal/wiki/Ansible-CICD#creating-a-pat-for-gpr-access)
for creating a new PAT if you don't have one. Once created, the same PAT can be
reused across projects.

#### For Users (Fetching the Gem)

To use this gem in another Ruby project, authenticate Bundler:

```sh
bundle config set --global https://rubygems.pkg.github.com/epimorphics USERNAME:TOKEN
```

Replace `USERNAME` with your GitHub username and `TOKEN` with your personal
access token.

#### For Developers (Working on the Gem)

Running `make auth` will prompt for your PAT and write it to `~/.gem/credentials`:

```sh
make auth
```

The same mechanism is used by the CI publication workflow, where the PAT is
supplied automatically via `secrets.GITHUB_TOKEN`.

## Development Workflow

### `Makefile` Commands

The project includes a `Makefile` with common development tasks:

- `make assets` — Install gem dependencies via Bundler
- `make auth` — Create GitHub and Bundler authorisations
- `make build` — Verify and build the gem (runs `clean`, `checks`, then `gem`)
- `make check` — Alias for `checks`
- `make checks` — Run linting and tests
- `make gem` — Build the gem artefact only
- `make lint` — Run Rubocop linting
- `make publish` — Push an existing gem artefact to the GitHub Package Registry
- `make tags` — Display version information for the CI pipeline
- `make test` — Run the test suite
- `make updates` — Check for outdated Ruby gems

The Makefile separates verification, packaging, and publishing so each stage can
be run independently and composed safely. CI enforces quality gates before
publishing, whilst local workflows can run verification and packaging together or
independently.

### Linting

Rubocop should not report any warnings:

```sh
$ make lint
Inspecting 21 files
.....................

21 files inspected, no offenses detected
```

`make lint` runs Rubocop with safe auto-correction (`-a`) for local developer
convenience. The CI workflow runs Rubocop without auto-correction and will fail
when offences are detected.

### Tests

You will need to have started the [HMLR Data API](https://github.com/epimorphics/lr-data-api)
locally. Follow the instructions in the repository's [README](https://github.com/epimorphics/lr-data-api#run).

Once the API is running, invoke the tests with:

```sh
make test
```

You can also set the environment variable `API_SERVICE_URL` to point to a
running instance on a non-default port:

```sh
API_SERVICE_URL=http://localhost:8080 make test
```

> [!NOTE]
> If `API_SERVICE_URL` is not set it defaults to `http://localhost:8888`.

## Publishing a New Version

To publish a new version of the gem after a bugfix or feature addition:

1. Make the required code changes and have them reviewed
2. Update `CHANGELOG.md` to document the new change
3. Update `lib/data_services_api/version.rb` following semantic versioning
4. Run `make build` locally to verify linting and tests pass before releasing
5. Merge the changes to `main`
6. Trigger the **Release and Publish Gem** workflow manually via the GitHub
   Actions UI — see the [workflows README](.github/workflows/README.md) for
   full instructions

The workflow runs Rubocop and the test suite as parallel quality gates before
publishing. The gem will appear on the [list of
releases](https://github.com/epimorphics/data_services_api/releases) once
complete.
