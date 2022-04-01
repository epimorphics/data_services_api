# Changelog for DS API rubygem

## 1.3.2 - 2022-04-01

- (Ian) Remove use of automated Faraday logging of API calls. Add manual
  logging of API calls, to conform to local best practice

## 1.3.1 - 2022-03-28

- (Ian) Add duration to reported ActiveSupport::Notification of API response

## 1.3.0 - 2022-03-22

- (Ian) Publish gem to Github package registry

## 1.2.1 - 2022-01-28

- (Ian) Fix minimum Ruby version constraint in gemspec.

## 1.2.0 - 2022-01-27

- (Ian) Added `ActiveSupport` instrumentation calls to allow collecting
  of metrics on API calls

## 1.1.1 - 2022-01-21

- (Ian) Added GitHub actions to run Rubucop and Minitest tests in CI

## 1.1.0 - 2021-10-28 (Bogdan)

- Added support for `@json_mode: "complete"` query parameter

## 1.0.0 - 2021-06-14 (Bogdan)

- Added a DSAPI to SapiNT converter, which converts all DSAPI queries
  to SapiNT queries and then sends them to a SapiNT backend

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
