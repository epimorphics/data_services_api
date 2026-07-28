# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Changed

- **Breaking**: `Faraday::ResourceNotFound`/`Faraday::ClientError`/
  `Faraday::ServerError`/`Faraday::ParsingError` (any 4xx/5xx status, or an
  unparseable response body) are no longer raised directly to callers.
  They're now always wrapped in `DataServicesApi::ServiceException` before
  being raised, restoring the exception contract that consuming
  applications were already written against (`e.service_message`, `e.status`)
  but that this gem had stopped actually providing
- Fixed `ServiceException#service_message`, which always returned `nil` due
  to a typo (`initialize` assigned `@service_msg` instead of `@service_message`)
- `service_exception.data_services_api` now fires for this whole class of
  failure (previously only `Faraday::ResourceNotFound`/404), and its
  `query_string` field is now populated correctly from the actual request
  params instead of always being `nil`
- Added a `retry.data_services_api` notification, fired immediately before
  each retry attempt on a network failure, with `path`, `method`,
  `retry_count`, `exception`, and `will_retry_in`

## 2.0.0

### Changed

- **Breaking**: `Service` no longer does any logging of its own. The `logger:`
  config option has been removed, along with the automatic `Rails.logger`
  wiring, the `puts` debug line, and all `logger.info`/`error`/etc calls.
  Consuming applications should subscribe to the gem's
  `ActiveSupport::Notifications` events instead and log whatever they need,
  at whatever level and format they choose
- **Breaking**: instrumentation event names are now namespaced under
  `data_services_api` instead of the generic, collision-prone `.api` suffix:
  `requests.api` -> `requests.data_services_api`,
  `response.api` -> `response.data_services_api`,
  `connection_failure.api` -> `connection_failure.data_services_api`,
  `service_exception.api` -> `service_exception.data_services_api`. A new
  `query_result.data_services_api` event carries the request path, method,
  status, and returned row count that used to only be visible in the removed
  log output
- **Breaking**: Faraday's built-in request/response logging middleware is no
  longer enabled automatically in Rails. It's now opt-in via
  `Service.new(faraday_logger:)`, passing a logger object to hand to Faraday.
  When enabled, it still defaults to logging at `debug` level with headers/
  bodies/errors off (matching the old always-on behaviour), configurable via
  `Service.new(faraday_logger_options:)`
- Fixed a bug where `service_exception.api`/`connection_failure.api` were
  never logged outside of a Rails environment; the new notification events
  fire consistently regardless of environment
- Fixed a `NameError` (`RACK::Exception` instead of `Rack::Exception`) in the
  service-exception error path that would raise whenever a `Faraday::ResourceNotFound`
  without a `status` reached it
- Removed the `yajl-ruby` dependency and the `Service#parser`/`parse_json`
  machinery built on it. Response bodies are already parsed to Ruby
  Hash/Array by Faraday's own `:json` response middleware; the removed code
  was re-serializing that result back to a JSON string and parsing it a
  second time with Yajl for no benefit. This also fixes the gem being broken
  out of the box for any consumer that didn't separately `require 'yajl'`
  themselves, since this gem's own `require "yajl"` had been commented out
- Removed the unused `faraday-encoding` dependency; nothing in the gem
  configures Faraday's `:encoding` middleware
- Fixed `Service#datasets`, which always raised `ArgumentError` (it called
  `api_get_json` with a missing required argument). Confirmed unused by
  every consuming app currently on this gem, which explains why it went
  unnoticed
- Fixed `Service#as_http_api`, which raised `URI::InvalidComponentError`
  whenever `url:` was configured with a scheme (exactly as the README's own
  usage example shows) and a relative path was passed to `api_get_json`/
  `api_post_json`. Also unused by any current consumer, since all existing
  calls happen to pass a full URL rather than a relative path
- Removed `Service#ok?`, which was unreachable in practice (Faraday's
  `raise_error` middleware already raises on all 4xx/5xx before `ok?` could
  run) and would have raised a `TypeError` itself if it ever did run, since
  `response.body` is already a parsed Hash by that point, not a JSON string
- Removed the dead, non-functional `auth` parameter from the private
  `create_http_connection`; no caller passed `auth: true`, and the
  `api_user`/`api_pw` methods it referenced don't exist
- Added a `connection_timeout` config option (defaulting to the previous
  hardcoded `600` seconds) for consistency with the other configurable
  retry/timeout options
- Extracted the duplicated request-timing/instrumentation/rescue logic in
  `get_from_api`/`post_to_api` into a shared `perform_request` helper

## 1.7.0 - 2026-07-13

### Added

- Support configuring `Faraday::ConnectionFailed` and `Faraday::TimeoutError`
  retry behaviour independently via `Service.new(connection_failed_retry_options:,
  timeout_retry_options:)`, defaulting connection failures to a more generous
  retry budget than timeouts

### Changed

- `Faraday::ResourceNotFound` (404) is no longer retried, since a 404 is not a
  transient failure and retrying it only adds latency

- Lowered minimum supported Ruby version and removed the pinned `.ruby-version`
  file in favor of explicit versions per CI workflow
- Added a CI test matrix covering Ruby 3.4 and 4.0
- Dropped the unmaintained `minitest-rg`, `minitest-vcr`, `minispec-metadata`,
  and `json_expressions` gems in favor of `minitest` 6, direct use of `vcr`,
  and plain JSON-normalized equality assertions
- Added explicit `cgi` dependency, required by `vcr` since Ruby 4.0 split it
  out of the standard library

## 1.6.1 - 2025-11

### Security

- Updated dependency versions to address security vulnerabilities:
  - Faraday HTTP client updated to 2.14.0 with related middleware
  - WebMock, Mocha, and Excon libraries updated to latest secure versions
  - Development and linting tools updated to compatible versions

  [#27](https://github.com/epimorphics/data_services_api/issues/27)

### Added

- New Make targets for linting, cleaning, asset management, and variable inspection
- Comprehensive help documentation in Makefile

### Changed

- Improved gemspec with enhanced metadata and dependency constraints
- Overhauled Makefile with comprehensive build automation
- Upgraded Bundler version for improved dependency management
- Refined file packaging configuration for better gem distribution
- Refined logger configuration for improved debugging:
  - Disabled logging of headers in HTTP responses
  - Turned off logging of errors in HTTP responses
  - Set log level to debug consistently across all environments
  - Removed production/debug environment-based log level logic
- Updated README documentation:
  - Switched build and test instructions from rake to make commands
  - Fixed typo in notifications reference for Prometheus monitoring section
- Updated additional dependencies:
  - Upgraded net-http to version 0.8.0 for improved compatibility
  - Bumped faraday-follow_redirects to require newer minor version

### Fixed

- Corrected middleware stack ordering in HTTP client to ensure proper error handling
- Updated gem homepage URL and project references for accuracy

## 1.6.0 - 2025-07

### Changed

- Updated TargetRubyVersion to 3.4 for compatibility
- Refreshed dependencies for better stability
- Refactored logging and error handling for clarity
- Enhanced JSON parsing reliability
- Revised VCR setups with new HTTP client
- Expanded .gitignore to cover more files
- Included Gemfile.lock for consistent dependencies

---
<!-- Versions below this point use legacy changelog format -->

## 1.5.4 - 2025-04

- (Jon) Adds returned row count to logs when the count is a positive integer.
  [GH-272](https://github.com/epimorphics/ppd-explorer/issues/272)

## 1.5.3 - 2025-04

- (Jon) Improved API request logging with query string information, which can
   assist in debugging and monitoring.
- (Jon) Reordered rescue statements to ensure error handling priority;
   connection failures are now handled after service exceptions.
- (Jon) Resolved a bug that caused an error when the API returns a nil item list
   by providing a default value of 0.

## 1.5.2 - 2025-03

- (Jon) Updated API logging and response handling
  - Changed log message for API request initiation.
  - Updated log message to reflect number of rows returned.
  - Modified request status from 'completed' to 'processing'.
  - Enhanced response parsing by renaming variable for clarity.
- (Jon)Updated logging for API requests
  - Changed log messages to include the origin of the URL.
  - Updated request status from 'received' to 'processing'.
  - Adjusted completion message to reflect the new origin format.
- (Jon) Enhanced logging with query string handling
  - Added conditional to append query string to path if present
  - Removed duplicate query string handling logic
  - Cleaned up log fields by setting query string to nil after use
  - Improved clarity in log message generation
- (Jon) Cleaned up service message generation
  - Removed unused query string parameter from method.
  - Simplified message construction logic.
  - Improved readability by reducing complexity.
- (Jon) Enhance logging parameters for API requests
  - Updated log_fields to include new parameters: path, query_string, method,
    and request_time.
  - Changed existing parameter names for clarity.
  - Improved handling of default values for message and status.
  - Added logic to clean up unwanted or nil values from log fields before
    logging.
- (Jon) Improve logging for service requests
  - Updated message generation to include completion details.
  - Simplified query string handling and added checks for nil/empty.
  - Changed request status from 'processing' to 'completed'.
  - Enhanced logged fields with method, path, and elapsed time.
- (Jon) Added detailed logging for incoming requests.
  - Included query string in log messages.
  - Improved service message generation with request details.
- (Jon) Improve service message generation
  - Removed unused parameters from the method.
  - Added handling for query strings and default values.
  - Improved message formatting with time taken.
- (Jon) Ensure exception message is a string
  - Changed exception.message to exception.message.to_s for logging.
  - Ensures consistency in log output when in Rails environment.
- (Jon) Enhanced logging with request time formatting
  - Added conditional check for request time presence
  - Improved request time format to include seconds and milliseconds
  - Updated log message structure for clarity
- (Jon) Included the HTTP method in the response log.
- (Jon) Set a default method value of 'GET' if not provided.
- (Jon) Ensured logs are sorted and cleaned up before final output.
- (Jon) Updated the instrumenter calls to include exceptions as a keyword
  argument for better clarity and consistency.
  [GH-465](https://github.com/epimorphics/ukhpi/issues/465)
- (Jon) Refactored logging functionality
  - Changed how start time is logged to keep it intact.
  - Cleared out nil values from log fields before logging.
  - Updated log messages for better clarity on service and timing.
- (Jon) Refactored error handling in service module
  - Changed `throw` to `raise` for better exception handling.
  - Rearranged rescue blocks for clearer flow.
  - Improved readability and maintainability of the code.
- (Jon) Updated the logging for data service requests.
  - Changed log message to be more concise.
  - Added response status to logged fields for better tracking.
- (Jon) Added pre-commit and pre-push hooks to prevent committing and pushing
  code that does not pass the linting and testing checks.
- (Jon) Adjusted the styling and linting rules to ensure the codebase adheres to
  the latest best practices.
- (Jon) Refactored test suite and fixed tests for the service class.
- (Jon) Added timing for API requests to log processing time.
- (Jon) Enhanced log messages with more detailed info about requests.
- (Jon) Updated methods to streamline error handling and logging.
- (Jon) Refactored connection creation to include retry logic.
- (Jon) Cleaned up method parameters for better readability.
- (Jon) Updated the `lib/data_services_api/service.rb` to include the
  `X-Request-Id` header in the SAPINT requests to match the header received from
  the apps using the gem.
- (Jon) Updated the `CHANGELOG.md` to include the new version changes
- (Jon) Updated the `lib/data_services_api/version.rb` to include the new
  version number `1.5.2`.
- (Jon) Updated the `lib/data_services_api/service.rb` for ignorable Rubocop
  warnings.
- (Jon) Implemented the `.github/workflows/publish.yml` workflow to publish the
  gem to the Epimorphics GitHub Package Registry.
- (Jon) Updated the `README.md` to include the new workflow and the `Makefile`
  to include the `publish` target to trigger the new workflow.
- (Jon) Unified improved logging for requests and responses to the SAPINT
  service, alongside improved comments and documentation.

## 1.5.1 - 2024-10-14

- (Jon) Fixed casing on the `X-Request-Id` header for SAPINT requests to match
  the header received from the apps using the gem.
  [GH-189](https://github.com/epimorphics/hmlr-ansible-deployment/issues/189)
- (Jon) Updated the previously supplied release date in the `v1.5.0` entry to
  match the actual release date.
- (Jon) Updated the `version.rb` `SUFFIX` entry to be `nil` by default to ensure
  the version number is correctly formatted.

## 1.5.0 - 2024-10-09

- (Dan) Updates ruby to 2.7.8 and version cadence to 1.5.0

## 1.4.1 - 2023-06-23

- (Jon) Now handles matching the message flag while ignoring the casing of the
  message
- (Jon) Better handling of reporting different logging levels using DRY
  principles
- (Jon) Resolves failing test for duration as integer

## 1.4.0 - 2023-06-21

- (Jon) New and improved logging on the service level
- (Jon) Inclusion of the `X-Request-Id` header to SAPINT requests
- (Jon) Updated service logger comments with better intentions
- (Jon) Improved Unit tests for the service logger

## 1.3.3- 2023-01

- (Jon) Refactors the elapsed time calculated for API requests to be resolved as
  microseconds rather than milliseconds. This is to improve the reporting of the
  elapsed time in the system tooling logs.
- (Jon) Resolves failing tests due to the improper invocation of mock objects
  without the correct arguments.
- (Jon) Minor text changes to the .gemspec file to update the description and
  summary of the gem as well as the name and email address for the maintainer.
- (Jon) Includes multiple updates and fixes to the codebase to resolve the
  majority of the Rubocop warnings.
- (Jon) Updated CI/CD workflows to use latest Epimorphics GitHub Actions
  versions.
- (Jon) Updated System test to include a test for the new elapsed time metric.
- (Jon) Refactored the linting settings to include lessons learned in other
  projects thereby improving the opinionated results from RuboCop to ensure the
  codebase adheres to current best practices.
- (Jon) Refactored the version cadence creation to include a SUFFIX value if
  provided; otherwise no SUFFIX is included in the version number.
- (Jon) Includes initial steps for better logging of API requests and responses
  to the system logs.
- (Jon) As part of the better logging updates the error message returned to the
  requesting app has been refactored to be more concise as well the failed
  connection error status has been set specifically to `503 Service
  Unavailable`.

## 1.3.2 - 2022-04-01

- (Ian) Remove use of automated Faraday logging of API calls. Add manual logging
  of API calls, to conform to local best practice

## 1.3.1 - 2022-03-28

- (Ian) Add duration to reported ActiveSupport::Notification of API response

## 1.3.0 - 2022-03-22

- (Ian) Publish gem to Github package registry

## 1.2.1 - 2022-01-28

- (Ian) Fix minimum Ruby version constraint in gemspec.

## 1.2.0 - 2022-01-27

- (Ian) Added `ActiveSupport` instrumentation calls to allow collecting of
  metrics on API calls

## 1.1.1 - 2022-01-21

- (Ian) Added GitHub actions to run Rubucop and Minitest tests in CI

## 1.1.0 - 2021-10-28 (Bogdan)

- Added support for `@json_mode: "complete"` query parameter

## 1.0.0 - 2021-06-14 (Bogdan)

- Added a DSAPI to SapiNT converter, which converts all DSAPI queries to SapiNT
  queries and then sends them to a SapiNT backend

## 0.4.5 - 2019-11-11

- dependency updates
- fixed some minor Rubocop warnings

## 0.4.4 - 2019-10-10

- dependency updates
- fixed deprecation warnings from minitest

## 0.4.3 2019-09-09

- dependency updates
- updated code to conform to latest Rubocop guides
- added Changelog
