.PHONY: auth clean gem publish test

NAME?=data_services_api
OWNER?=epimorphics
VERSION?=$(shell ruby -e 'require "./lib/${NAME}/version" ; puts DataServicesApi::VERSION')
PAT?=$(shell read -p 'Github access token:' TOKEN; echo $$TOKEN)

AUTH=${HOME}/.gem/credentials
GEM=${NAME}-${VERSION}.gem
GPR=https://rubygems.pkg.github.com/${OWNER}
SPEC=${NAME}.gemspec

all: publish

${AUTH}:
	@mkdir -p ${HOME}/.gem
	@echo '---' > ${AUTH}
	@echo ':github: Bearer ${PAT}' >> ${AUTH}
	@chmod 0600 ${AUTH}

${GEM}: ${SPEC} ./lib/${NAME}/version.rb
	gem build ${SPEC}

assets:
	@echo "Installing assets for ${NAME} gem..."
	@bundle install
	@echo "Assets for ${NAME} gem are up to date."

auth: ${AUTH}

build: clean gem

clean:
	@echo "Cleaning up ${NAME} gem..."
	@bundle exec rake clean clobber
	@rm -rf ${GEM}

gem: ${GEM}
	@echo ${GEM}

lint:
	@echo "Running RuboCop for ${NAME} gem..."
	@bundle exec rubocop
	@echo "RuboCop checks completed."

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
	@echo "NAME=${NAME}"
	@echo "OWNER=${OWNER}"
	@echo "VERSION=${VERSION}"
	@echo "GEM=${GEM}"
	@echo "GPR=${GPR}"
	@echo "SPEC=${SPEC}"
