# Copyright (c) 2021 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# Contributors:
#   Red Hat, Inc. - initial API and implementation
#

export DASHBOARD_NAMESPACE ?= dashboard-backend
export DASHBOARD_IMG ?= quay.io/jpinkney/devworkspace-client:latest

all: help

_print_vars:
	@echo "Current env vars:"
	@echo "    DASHBOARD_NAMESPACE=$(DASHBOARD_NAMESPACE)"
	@echo "    DASHBOARD_IMG=$(DASHBOARD_IMG)"

ifeq (,$(shell which kubectl))
ifeq (,$(shell which oc))
$(error oc or kubectl is required to proceed)
else
K8S_CLI := oc
endif
else
K8S_CLI := kubectl
endif

ifeq ($(shell $(K8S_CLI) api-resources --api-group='route.openshift.io'  2>&1 | grep -o routes),routes)
PLATFORM := openshift
else
PLATFORM := kubernetes
endif

### build_local: build the dashboard backend locally
build_local:
	yarn run build

### run_local: run the dashboard backend locally
run_local:
	node dist/server.js

### local: build and run the dashboard backend locally
local: build_local run_local

### docker_build: build the dashboard backend image
docker_build:
	docker build . -t ${DASHBOARD_IMG}

### docker_push: push the dashboard backend image
docker_push:
	docker push ${DASHBOARD_IMG}

### build_and_push: build the container and push to quay
build_and_push: docker_build docker_push

### install: Install the dashboard backend to the cluster
install:
	$(K8S_CLI) apply -f deploy/deployment.yaml
	$(K8S_CLI) apply -f deploy/role.yaml
	$(K8S_CLI) apply -f deploy/rolebinding.yaml
	$(K8S_CLI) apply -f deploy/serviceaccount.yaml
ifeq ($(PLATFORM),kubernetes)
	$(info    Kubernetes specific deployments are not currently supported)
else
	$(K8S_CLI) apply -f deploy/openshift
endif

### uninstall: Uninstall the dashboard backend from the cluster
uninstall:
	$(K8S_CLI) delete all -l "app.kubernetes.io/part-of=dashboard-backend" --all-namespaces

.PHONY: help
### help: print this message
help: Makefile
	@echo 'Available rules:'
	@sed -n 's/^### /    /p' $< | awk 'BEGIN { FS=":" } { printf "%-30s -%s\n", $$1, $$2 }'
	@echo ''
	@echo 'Supported environment variables:'
	@echo '    DASHBOARD_NAMESPACE        - Namespace to use for deploying the dashboard backend'
	@echo '    DASHBOARD_IMG              - Image used for the dashboard backend'
