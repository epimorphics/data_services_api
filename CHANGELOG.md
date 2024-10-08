# Changelog for DS API rubygem

## 1.5.0 - 2023-06-23

- (Dan) Updates ruby to 2.7.8 and version cadence to 1.5.0

## 1.4.1 - 2023-06-23

- (Jon) Now handles matching the message flag while ignoring the casing of the message
- (Jon) Better handling of reporting different logging levels using DRY principles
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
  connection error status has been set specifically to `503 Service Unavailable`.

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
