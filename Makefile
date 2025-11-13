.PHONY: auth clean gem publish test

NAME?=data_services_api
OWNER?=epimorphics
VERSION?=$(shell ruby -e 'require "./lib/${NAME}/version" ; puts DataServicesApi::VERSION')
PAT?=$(shell read -p 'Github access token:' TOKEN; echo $$TOKEN)

AUTH=${HOME}/.gem/credentials
GEM=${NAME}-${VERSION}.gem
GPR=https://rubygems.pkg.github.com/${OWNER}
SPEC=${NAME}.gemspec

${AUTH}:
	@mkdir -p ${HOME}/.gem
	@echo '---' > ${AUTH}
	@echo ':github: Bearer ${PAT}' >> ${AUTH}
	@chmod 0600 ${AUTH}

${GEM}: ${SPEC} ./lib/${NAME}/version.rb
	gem build ${SPEC}

all: publish

assets:
	@echo "Installing assets for ${NAME} gem..."
	@bundle install
	@echo "Assets for ${NAME} gem are up to date."

auth: ${AUTH}

build: clean gem

checks: lint test

clean:
	@echo "Cleaning up ${NAME} gem..."
	@bundle exec rake clean clobber
	@rm -rf ${GEM}

gem: ${GEM}
	@echo ${GEM}

help:
	@echo "Make targets:"
	@echo "  all - build the Docker image (default)"
	@echo "  assets - install gems and yarn packages, compile assets"
	@echo "  auth - compile the required package registry authorisations"
	@echo "  build - build the gem package"
	@echo "  checks - run all linting and tests as a single task"
	@echo "  clean - remove temporary files"
	@echo "  gem - show the gem file name"
	@echo "  help - show this help message"
	@echo "  lint - run linters"
	@echo "  publish - release the image to the Docker registry"
	@echo "  realclean - remove all authentication tokens"
	@echo "  tags - show the current name, owner and version tags"
	@echo "  test - runs the test suite, be it units or integration"
	@echo "  vars - show the current variable settings"
	@echo "  version - show the current version"
	@echo ""
	@echo "Environment variables (optional: all variables have defaults):"
	@echo "  GEM - package name of the gem file (default: ${NAME}-${VERSION}.gem)"
	@echo "  GPR - GitHub package registry for gem (default: from git config)"
	@echo "  NAME - name of the Gem (default: from deployment.yaml)"
	@echo "  PAT - GitHub personal access token (default: prompt)"
	@echo "  SPEC - gemspec file to use (default: ${NAME}.gemspec)"
	@echo "  VERSION - version of the application (default: from VERSION file)"

lint:
	@echo "Running code linting for ${NAME} ..."
# Auto-correct offenses safely where possible with the `-a` flag
	@bundle exec rubocop -a
	@echo "Linting checks completed."

publish: ${AUTH} ${GEM}
	@echo Publishing package ${NAME}:${VERSION} to ${OWNER} ...
	@gem push --key github --host ${GPR} ${GEM}
	@echo Done.

realclean: clean
	@rm -rf ${AUTH}

tags:
	@echo name=${NAME}
	@echo owner=${OWNER}
	@echo version=${VERSION}

test: assets gem
	@bundle exec rake test
	@echo "Tests completed successfully."

vars:
	@echo "GEM=${GEM}"
	@echo "GPR=${GPR}"
	@echo "NAME=${NAME}"
	@echo "OWNER=${OWNER}"
	@echo "SPEC=${SPEC}"
	@echo "VERSION=${VERSION}"

version:
	@echo ${VERSION}
