## @author Copyright (C) 2015,2019 Robin Schneider <ypid@riseup.net>
## @license AGPL-3.0-only <https://www.gnu.org/licenses/agpl-3.0.html>

# export PATH := debuerreotype/scripts/:$(PATH)

SHELL ?= /bin/bash -o nounset -o pipefail -o errexit
MKIMAGE_OPTIONS ?= --no-compression
APT_PROXY_URL ?= $(shell apt-config dump | grep -i '^Acquire::HTTP::Proxy ' | cut '--delimiter="' --fields 2)
DOCKER_MAKEFILE_DIR_PATH := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
DOCKER_BUILD_DEBIAN_ADDITIONAL_PACKAGES ?= wget,curl
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

.PHONY: build-debian-stretch-base-image
build-debian-stretch-base-image: apt_proxy.conf
	rm -rf "$(DOCKER_BUILD_DIR)/$@"
	$(DOCKER_MAKEFILE_DIR_PATH)/mkimage.sh -t $(DOCKER_REGISTRY_PREFIX)debian:stretch $(MKIMAGE_OPTIONS) --dir "$(DOCKER_BUILD_DIR)/$@" debootstrap --include="$(DOCKER_BUILD_DEBIAN_ADDITIONAL_PACKAGES)" --variant=minbase stretch "$(APT_PROXY_URL)/deb.debian.org/debian"
	rm -rf "$(DOCKER_BUILD_DIR)/$@"

.PHONY: build-debian-buster-base-image
build-debian-buster-base-image: apt_proxy.conf
	rm -rf "$(DOCKER_BUILD_DIR)/$@"
	$(DOCKER_MAKEFILE_DIR_PATH)/mkimage.sh -t $(DOCKER_REGISTRY_PREFIX)debian:buster $(MKIMAGE_OPTIONS) --dir "$(DOCKER_BUILD_DIR)/$@" debootstrap --include="$(DOCKER_BUILD_DEBIAN_ADDITIONAL_PACKAGES)" --variant=minbase buster "$(APT_PROXY_URL)/deb.debian.org/debian"
	docker tag $(DOCKER_REGISTRY_PREFIX)debian:buster $(DOCKER_REGISTRY_PREFIX)debian:buster-slim
	rm -rf "$(DOCKER_BUILD_DIR)/$@"

.PHONY: build-debian-buster-latest-snapshot-base-image
build-debian-buster-latest-snapshot-base-image: apt_proxy.conf
	rm -rf "$(DOCKER_BUILD_DIR)/$@"
	mkdir -p "$(DOCKER_BUILD_DIR)/$@"
	debuerreotype-init --arch amd64 --no-merged-usr --non-debian "$(DOCKER_BUILD_DIR)/$@" buster http://cache:3142/snapshot.debian.org/archive/debian/20210621T212047Z
	debuerreotype-minimizing-config "$(DOCKER_BUILD_DIR)/$@"
	debuerreotype-debian-sources-list --snapshot "$(DOCKER_BUILD_DIR)/$@" buster
	cp apt_proxy.conf "$(DOCKER_BUILD_DIR)/$@/etc/apt/apt.conf.d/apt.conf"
	echo 'Acquire::Check-Valid-Until "false";' > "$(DOCKER_BUILD_DIR)/$@/etc/apt/apt.conf.d/00debuerreotype_snapshot"
	tar -cC "$(DOCKER_BUILD_DIR)/$@" . | docker import - $(DOCKER_REGISTRY_PREFIX)debian:buster-20210621
	# ./debuerreotype/examples/debian.sh --arch amd64  'buster' '@1612742400'
	# $(DOCKER_MAKEFILE_DIR_PATH)/mkimage.sh -t $(DOCKER_REGISTRY_PREFIX)debian:buster $(MKIMAGE_OPTIONS) --dir "$(DOCKER_BUILD_DIR)/$@" debootstrap --include="$(DOCKER_BUILD_DEBIAN_ADDITIONAL_PACKAGES)" --variant=minbase buster "$(APT_PROXY_URL)/deb.debian.org/debian"
	docker tag $(DOCKER_REGISTRY_PREFIX)debian:buster-20210621 $(DOCKER_REGISTRY_PREFIX)debian:buster-20210621-slim
	rm -rf "$(DOCKER_BUILD_DIR)/$@"

.PHONY: build-ubuntu-cosmic-base-image
build-ubuntu-cosmic-base-image: apt_proxy.conf
	rm -rf "$(DOCKER_BUILD_DIR)/$@"
	$(DOCKER_MAKEFILE_DIR_PATH)/mkimage.sh -t $(DOCKER_REGISTRY_PREFIX)ubuntu:cosmic $(MKIMAGE_OPTIONS) --dir "$(DOCKER_BUILD_DIR)/$@" debootstrap --include="ubuntu-minimal,$(DOCKER_BUILD_DEBIAN_ADDITIONAL_PACKAGES)" --components=main,universe --variant=minbase cosmic "$(APT_PROXY_URL)/archive.ubuntu.com/ubuntu"
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
