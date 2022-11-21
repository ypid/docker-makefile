# SPDX-FileCopyrightText: 2015,2019,2022 Robin Schneider <ypid@riseup.net>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

SHELL = /bin/bash
.ONESHELL:
MAKEFLAGS += --no-builtin-rules
.SUFFIXES:

APT_PROXY_URL ?= $(shell apt-config dump | grep -i '^Acquire::HTTP::Proxy ' | cut '--delimiter="' --fields 2)
DOCKER_MAKEFILE_DIR_PATH := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
DOCKER_BUILD_DIR ?= /var/lib/docker-build
DOCKER_REGISTRY_SOCKET ?=
# DOCKER_REGISTRY_SOCKET ?= localhost:5000
DOCKER_REGISTRY_PREFIX ?= $(DOCKER_REGISTRY_SOCKET)/
ARCH ?= $(shell dpkg --print-architecture)

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
$(DOCKER_BUILD_DIR)/%/.done: apt_proxy.conf
	@set -o nounset -o pipefail -o errexit
	yyyymmdd="$$(echo $@ | sed -E 's/.*([0-9]{8}).*/\1/;')"
	yyyy_dd_mm="$$(echo $@ | sed -E 's/.*([0-9]{4})([0-9]{2})([0-9]{2}).*/\1-\2-\3/;')"
	distro_codename="$(*F)"
	arch="$$(echo $@ | sed -E 's#.*[0-9]{8}/([^/]+)/.*#\1#;')"
	set -o xtrace

	rm "$(@D)" -rf
	$(DOCKER_MAKEFILE_DIR_PATH)/debuerreotype/examples/debian.sh --arch="$${arch}" "$(DOCKER_BUILD_DIR)" "$${distro_codename}" "$${yyyy_dd_mm}T00:00:00Z"

	docker import "$(@D)/rootfs.tar.xz" "$(DOCKER_REGISTRY_PREFIX)debian:$${distro_codename}-$${yyyymmdd}"
	echo "FROM $(DOCKER_REGISTRY_PREFIX)debian:$${distro_codename}-$${yyyymmdd}" > Dockerfile
	echo "ADD apt_proxy.conf /etc/apt/apt.conf" >> Dockerfile
	docker build . --tag "$(DOCKER_REGISTRY_PREFIX)debian:$${distro_codename}-$${yyyymmdd}"
	docker tag "$(DOCKER_REGISTRY_PREFIX)debian:$${distro_codename}-$${yyyymmdd}" "$(DOCKER_REGISTRY_PREFIX)debian:$${distro_codename}"

	# This is technically wrong. debuerreotype even builds a slim variant. I still just use the full as slim to save push/pull time.
	docker tag "$(DOCKER_REGISTRY_PREFIX)debian:$${distro_codename}-$${yyyymmdd}" "$(DOCKER_REGISTRY_PREFIX)debian:$${distro_codename}-$${yyyymmdd}-slim"
	docker tag "$(DOCKER_REGISTRY_PREFIX)debian:$${distro_codename}-$${yyyymmdd}" "$(DOCKER_REGISTRY_PREFIX)debian:$${distro_codename}-slim"

	rm -rf Dockerfile
	touch "$@"

# To get the latest timestamp check https://docker.debian.net/ (quicker than https://hub.docker.com/_/debian/tags)
.PHONY: build-debian-bullseye-snapshot-base-image
build-debian-bullseye-snapshot-base-image: $(DOCKER_BUILD_DIR)/20221114/$(ARCH)/bullseye/.done

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
