# SPDX-FileCopyrightText: 2015,2019,2022 Robin Schneider <ypid@riseup.net>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

SHELL ?= /bin/bash -o nounset -o pipefail -o errexit
MAKEFLAGS += --no-builtin-rules
.SUFFIXES:

APT_PROXY_URL ?= $(shell apt-config dump | grep -i '^Acquire::HTTP::Proxy ' | cut '--delimiter="' --fields 2)
DOCKER_MAKEFILE_DIR_PATH := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
DOCKER_BUILD_DIR ?= /var/lib/docker-build
DOCKER_REGISTRY_SOCKET ?=
# DOCKER_REGISTRY_SOCKET ?= localhost:5000
DOCKER_REGISTRY_PREFIX ?= $(DOCKER_REGISTRY_SOCKET)/

export PATH := $(DOCKER_MAKEFILE_DIR_PATH)/debuerreotype/scripts:$(PATH)

## Common targets {{{
default:
	@echo See Makefile

clean: remove-all-dangling-images

## }}}

## Build base images {{{

apt_proxy.conf:
	apt-config dump | egrep -i '^Acquire::HTTPS?::Proxy\b' > "$@"

# Requires https://github.com/debuerreotype/debuerreotype. 0.10-2 in Debian 11 is not sufficient (image is missing APT sources).
# To get the latest timestamp check https://docker.debian.net/ (quicker than https://hub.docker.com/_/debian/tags)
$(DOCKER_BUILD_DIR)/20221114/: apt_proxy.conf
	$(DOCKER_MAKEFILE_DIR_PATH)/debuerreotype/examples/debian.sh "$(shell dirname "$@")" bullseye 2022-11-14T00:00:00Z
	docker import "$@/amd64/bullseye/rootfs.tar.xz" $(DOCKER_REGISTRY_PREFIX)debian:bullseye-20221114
	echo "FROM $(DOCKER_REGISTRY_PREFIX)debian:bullseye-20221114" > Dockerfile
	echo "ADD apt_proxy.conf /etc/apt/apt.conf" >> Dockerfile
	docker build . --tag $(DOCKER_REGISTRY_PREFIX)debian:bullseye-20221114

	# This is technically wrong. debuerreotype even builds a slim variant. I still just use the full as slim to save push/pull time.
	docker tag $(DOCKER_REGISTRY_PREFIX)debian:bullseye-20221114 $(DOCKER_REGISTRY_PREFIX)debian:bullseye-20221114-slim

	rm -rf Dockerfile

.PHONY: build-debian-bullseye-snapshot-base-image
build-debian-bullseye-snapshot-base-image: $(DOCKER_BUILD_DIR)/20221114/

## }}}

list-docker-registry-images:
	curl 'https://$(DOCKER_REGISTRY_SOCKET)/v2/_catalog' | jq '.repositories'

tag-into-global-namespace:
	@docker images --filter=reference='$(DOCKER_REGISTRY_SOCKET)/*/*:*' --format '{{.Repository}}:{{.Tag}}' | while read -r ref; do \
		global_ref="$${ref##*/}"; \
		echo "$$ref -> $$global_ref"; \
		docker tag "$$ref" $$global_ref; \
	done

push-to-registry:
	@docker images --filter=reference='$(DOCKER_REGISTRY_PREFIX)*:*' --format '{{.Repository}}:{{.Tag}}' | grep -v ':<none>$$' | while read -r ref; do \
		docker push "$$ref"; \
	done

remove-all-dangling-images:
	-docker image prune --force
