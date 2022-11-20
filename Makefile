# SPDX-FileCopyrightText: 2015,2019 Robin Schneider <ypid@riseup.net>
#
# SPDX-License-Identifier: AGPL-3.0-only

# export PATH := debuerreotype/scripts/:$(PATH)

SHELL ?= /bin/bash -o nounset -o pipefail -o errexit
MKIMAGE_OPTIONS ?= --no-compression
APT_PROXY_URL ?= $(shell apt-config dump | grep -i '^Acquire::HTTP::Proxy ' | cut '--delimiter="' --fields 2)
DOCKER_BUILD_DIR ?= /var/lib/docker-build
DOCKER_REGISTRY_SOCKET ?=
# DOCKER_REGISTRY_SOCKET ?= localhost:5000
DOCKER_REGISTRY_PREFIX ?= $(DOCKER_REGISTRY_SOCKET)/


## Common targets {{{
default:
	@echo See Makefile

clean: remove-all-dangling-images

## }}}

## Build base images {{{

.PHONY: apt_proxy.conf FORCE_MAKE

apt_proxy.conf:
	apt-config dump | egrep -i '^Acquire::HTTPS?::Proxy\b' > "$@"

# Requires https://github.com/debuerreotype/debuerreotype. 0.10-2 in Debian 11 is not sufficient (image is missing APT sources).
.PHONY: build-debian-bullseye-snapshot-base-image
build-debian-bullseye-snapshot-base-image: apt_proxy.conf
	rm -rf "$(DOCKER_BUILD_DIR)/$@"
	mkdir -p "$(DOCKER_BUILD_DIR)/$@"
	debuerreotype-init --arch amd64 --no-merged-usr --non-debian "$(DOCKER_BUILD_DIR)/$@" bullseye http://cache:3142/snapshot.debian.org/archive/debian/20221114T000000Z
	debuerreotype-minimizing-config "$(DOCKER_BUILD_DIR)/$@"
	debuerreotype-debian-sources-list --snapshot "$(DOCKER_BUILD_DIR)/$@" bullseye
	cp apt_proxy.conf "$(DOCKER_BUILD_DIR)/$@/etc/apt/apt.conf.d/apt.conf"
	echo 'Acquire::Check-Valid-Until "false";' > "$(DOCKER_BUILD_DIR)/$@/etc/apt/apt.conf.d/00debuerreotype_snapshot"
	tar -cC "$(DOCKER_BUILD_DIR)/$@" . | docker import - $(DOCKER_REGISTRY_PREFIX)debian:bullseye-20221114
	# ./debuerreotype/examples/debian.sh --arch amd64  'bullseye' '@1612742400'
	docker tag $(DOCKER_REGISTRY_PREFIX)debian:bullseye-20221120 $(DOCKER_REGISTRY_PREFIX)debian:bullseye-20221120-slim
	rm -rf "$(DOCKER_BUILD_DIR)/$@"

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
