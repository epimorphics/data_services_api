# Changelog for DS API rubygem

## 1.5.2 - 2025-02

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
