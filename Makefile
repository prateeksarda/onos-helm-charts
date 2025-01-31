.PHONY: all test clean

all: test

jenkins-test: jenkins_version_check # @HELP run the jenkins verification tests
	docker pull quay.io/helmpack/chart-testing:v2.4.0
	docker run --rm --name ct --volume `pwd`:/charts quay.io/helmpack/chart-testing:v3.0.0-beta.1 sh -c "ct lint --charts charts/onos-config,charts/onos-topo,charts/onos-cli,charts/onos-gui,charts/device-simulator --debug --validate-maintainers=false"

test: # @HELP run the integration tests
test: version_check yang-lint
	kubectl create ns onos-topo && helmit test -n onos-topo ./test -c . --suite onos-topo
	kubectl create ns onos-config && helmit test -n onos-config ./test -c . --suite onos-config
	kubectl create ns onos-umbrella && helmit test -n onos-umbrella ./test -c . --suite onos-umbrella

version_check: build-tools # @HELP run the version checker on the charts
	COMPARISON_BRANCH=master ./../build-tools/chart_version_check
	./../build-tools/chart_single_check

jenkins_version_check: build-tools # @HELP run the version checker on the charts
	export COMPARISON_BRANCH=origin/master && export WORKSPACE=`pwd` && ./../build-tools/chart_version_check
	./../build-tools/chart_single_check

publish: build-tools # @HELP publish version on github
	./../build-tools/publish-version ${VERSION}

jenkins-publish: build-tools # @HELP publish version on github
	cd .. && GO111MODULE=on go get github.com/mikefarah/yq/v4
	./../build-tools/release-chart-merge-commit https://charts.onosproject.org ${WEBSITE_USER} ${WEBSITE_PASSWORD}

build-tools: # @HELP install the ONOS build tools if needed
	@if [ ! -d "../build-tools" ]; then cd .. && git clone https://github.com/onosproject/build-tools.git; fi

bumponosdeps: build-tools # @HELP update "onosproject" go dependencies and push patch to git.
	./../build-tools/bump-onos-deps ${VERSION}

yang-lint: # @HELP install the ONOS build tools if needed
yang-lint: pyang-tool
	pyang --lint config-models/testdevice-2.x/files/yang/*.yang

pyang-tool: # @HELP install the Pyang tool if needed
	pyang --version || python -m pip install pyang==0.2.4

clean: # @HELP clean up temporary files.
	rm -rf onos-umbrella/charts onos-umbrella/Chart.lock

deps: # @HELP build dependencies for local charts.
deps: clean
	helm dep build onos-umbrella

help:
	@grep -E '^.*: *# *@HELP' $(MAKEFILE_LIST) \
    | sort \
    | awk ' \
        BEGIN {FS = ": *# *@HELP"}; \
        {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}; \
    '
