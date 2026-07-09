.PHONY: auth gem publish tags

NAME=data_services_api
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

auth: ${AUTH}

gem: ${GEM}
	@echo ${GEM}

publish: ${AUTH} ${GEM}
	@echo Publishing package ${NAME}:${VERSION} to ${OWNER} ...
	@gem push --key github --host ${GPR} ${GEM}
	@echo Done.

tags:
	@echo name=${NAME}
	@echo owner=${OWNER}
	@echo version=${VERSION}
