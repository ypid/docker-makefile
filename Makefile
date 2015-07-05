## @license AGPLv3 <https://www.gnu.org/licenses/agpl-3.0.html>
## @author Copyright (C) 2015 Robin Schneider <ypid@riseup.net>
##
## This program is free software: you can redistribute it and/or modify
## it under the terms of the GNU Affero General Public License as
## published by the Free Software Foundation, version 3 of the
## License.
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU Affero General Public License for more details.
##
## You should have received a copy of the GNU Affero General Public License
## along with this program.  If not, see <https://www.gnu.org/licenses/>.

ARGS ?= ''
FQDN ?= 'example.com'
SHELL   ?= /bin/bash
conf_dir ?= /etc/docker
DOCKER_BUILD_OPTIONS ?= --no-cache
docker_build_dir ?= /var/srv/docker
docker_build_debian_version ?= jessie
docker_build_debian_additional_programs ?= ,rename,iproute2

# image_openvpn ?= localbuild/openvpn
image_openvpn ?= localbuild/openvpn_new
# image_tor_server ?= patrickod/docker-tor_localbuild
image_tor_server ?= localbuild/tor-server_debian
image_postgres ?= localbuild/postgres
# image_owncloud ?= localbuild/owncloud_ubuntu
# image_owncloud ?= localbuild/owncloud_debian
image_owncloud ?= localbuild/owncloud_debian_new
image_seafile ?= localbuild/seafile
# image_nginx_php ?= localbuild/phpnginx
# image_nginx_php ?= zolweb/docker-phpnginx
image_nginx_php ?= maxexcloo/nginx-php
image_freeswitch ?= localbuild/freeswitch
image_ejabberd ?= localbuild/ejabberd
image_chatbot_err ?= localbuild/chatbot_err
# image_chatbot_program_o ?= localbuild/program_o
image_chatbot_program_o ?= localbuild/chatbot_program_o
image_chatbot_howie ?= localbuild/chatbot_howie
image_bittorrent ?= localbuild/bittorrent

default:
	echo See Makefile

snapshots:
	for i in /etc/snapper/configs/*; do snapper -c "`basename $i`" create -d 'Created by Makefile for docker'; done

stop-all:
	docker stop `docker ps -q`

install-images:
	docker pull jwilder/docker-gen
	# Updates not needed/wanted

.PHONY: apt-cacher-ng FORCE_MAKE
apt-cacher-ng:
	@(echo "Acquire::http::Proxy \"$(shell apt-config dump | grep '^Acquire::http::Proxy' | cut '--delimiter="' --fields 2)\"; };"; \
	echo "Acquire::https::Proxy \"false\";") > "$@"

build-debian-base-image: apt-cacher-ng
	-$(conf_dir)/docker-makefile/mkimage.sh -t localbuild/debian:$(docker_build_debian_version) --dir $(docker_build_dir) debootstrap --include=git,ca-certificates$(docker_build_debian_additional_programs) --variant=minbase $(docker_build_debian_version) "$(shell apt-config dump | grep '^Acquire::http::Proxy' | cut '--delimiter="' --fields 2)/http.debian.net/debian"
	@image=`docker images | egrep 'localbuild/debian\s+$(docker_build_debian_version)'`; \
	echo $$image; \
	id="`echo $$image | awk '{ print $$3 }'`"; \
	docker tag --force $$id debian:latest; \
	docker tag --force $$id debian:8; \
	docker tag --force $$id debian:8.0; \
	docker tag --force $$id debian:$(docker_build_debian_version)

upgrade-debian-base-image: build-debian-base-image
	# cd /var/srv/docker/docker-32bit-debian/ && ./upgrade-image.sh

## build {{{
.PHONY: build-image-tor

build-image-tor:
	-cd "$(conf_dir)/docker-tor" && git pull && docker build $(DOCKER_BUILD_OPTIONS) --tag $(image_tor_server) .

build-image-owncloud:
	-cd "$(conf_dir)/docker-owncloud" && git pull && docker build $(DOCKER_BUILD_OPTIONS) --tag $(image_owncloud) .

build-image-seafile:
	## Used by seafile
	# docker pull phusion/baseimage
	-cd "$(conf_dir)/docker-seafile" && git pull && docker build $(DOCKER_BUILD_OPTIONS) --tag $(image_seafile) .
	# docker pull jenserat/seafile

build-image-freeswitch:
	-cd "$(conf_dir)/freeswitch" && git pull && docker build $(DOCKER_BUILD_OPTIONS) --tag $(image_freeswitch) .

build-image-chatbot-program-o:
	# -cd "$(conf_dir)/docker-program-o" && docker build $(DOCKER_BUILD_OPTIONS) --tag $(image_chatbot_program_o) .
	-cd "$(conf_dir)/docker-program-o" && git pull && docker build --tag $(image_chatbot_program_o) .

build-image-chatbot-err:
	-cd "$(conf_dir)/docker-err" && git pull && docker build $(DOCKER_BUILD_OPTIONS) --tag $(image_chatbot_err) .

build-image-chatbot-howie:
	-cd "$(conf_dir)/docker-howie" && git pull && docker build $(DOCKER_BUILD_OPTIONS) --tag $(image_chatbot_howie) .

build-image-ejabberd:
	-cd "$(conf_dir)/docker-ejabberd" && git pull && docker build $(DOCKER_BUILD_OPTIONS) --tag $(image_ejabberd) .
	# docker pull rroemhild/ejabberd

build-image-openvpn:
	-cd "$(conf_dir)/docker-openvpn" && git pull && docker build $(DOCKER_BUILD_OPTIONS) --tag $(image_openvpn) .

build-image-postgres:
	-cd "$(conf_dir)/docker-postgres/9.4" && git pull && docker build $(DOCKER_BUILD_OPTIONS) --tag $(image_postgres) .

build-image-bittorrent:
	-cd "$(conf_dir)/docker-bittorrent" && git pull && docker build $(DOCKER_BUILD_OPTIONS) --tag $(image_bittorrent) .

prefetch-packages:
	# -cd "$(conf_dir)/apt_package_lists" && docker build $(DOCKER_BUILD_OPTIONS) .
	-cd "$(conf_dir)/apt_package_lists" && git pull && docker build .

## legacy {{{
build-image-nginx_php:
	-cd "$(conf_dir)/docker-phpnginx" && git pull && docker build $(DOCKER_BUILD_OPTIONS) --tag $(image_nginx_php) .
## }}}
## }}}

## tor server {{{
tor-relay:
	-@docker rm -f "$@"
	docker run -d \
		--name "$@" \
		-v /etc/tor/relay/torrc:/etc/tor/torrc \
		-v /srv/tor:/var/lib/tor \
		-e "TZ=Europe/Berlin" \
		-p 993:993 \
		-p 465:465 \
		$(image_tor_server) \
		/usr/bin/tor -f /etc/tor/torrc
		# -v /srv/tor:/var/lib/tor \

tor-hidden-services:
	-@docker rm -f "$@"
	docker run -d \
		--name "$@" \
		-v /etc/tor/hidden_services:/etc/tor \
		-v /srv/tor_hidden_service:/var/lib/tor \
		--publish-all=false \
		-e "TZ=Europe/Berlin" \
		$(image_tor_server) \
		/usr/bin/tor -f /etc/tor/torrc
		# -v /srv/tor:/var/lib/tor \
## }}}

## Bittorrent {{{
.PHONY: bittorrent
bittorrent:
	-@docker rm -f "$@"
	docker run -it \
		--name "$@" \
		-e "TZ=Europe/Berlin" \
		-e 'VIRTUAL_PATH=~rs/bittorrent' \
		-e 'VIRTUAL_SERVER_TYPE=rutorrent' \
		-p 45566:45566 \
		-p 9527:9527/udp \
		-v /srv/bittorrent:/rtorrent \
		-v /etc/rtorrent/htpasswd:/etc/nginx/htpasswd:ro \
		-v /etc/rtorrent/nginx:/etc/nginx/sites-available/default:ro \
		-e UPLOAD_RATE=500 \
		$(image_bittorrent)
		# -v /etc/rtorrent/rtorrent.rc:/root/.rtorrent.rc \
		# -p 801:80 \
## }}}

## owncloud {{{
.PHONY: owncloud-demo
owncloud-demo:
	-@docker rm -f "$@"
	docker run -d \
		--name "$@" \
		-h "$(FQDN)" \
		--link owncloud-db:db \
		-v /srv/rs/owncloud/data:/var/www/owncloud/data \
		-v /srv/rs/owncloud/apps_persistent:/var/www/owncloud/apps_persistent \
		-v /srv/rs/owncloud/config.php:/owncloud/config.php \
		-e 'VIRTUAL_PATH=~rs/owncloud' \
		-e 'VIRTUAL_SERVER_TYPE=owncloud' \
		-e 'VIRTUAL_PORT=80' \
		-e "TZ=Europe/Berlin" \
		$(image_owncloud)
# "apps_paths" => array (
#   0 => array (
#     "path"     => OC::$SERVERROOT."/apps",
#     "url"      => "/apps",
#     "writable" => false,
#   ),
#   1 => array (
#     "path"     => OC::$SERVERROOT."/apps_persistent",
#     "url"      => "/apps_persistent",
#     "writable" => true,
#   ),
# ),
# cd /var/www/ && mkdir '~user_a'&& ln -s ../owncloud '~user_a/'
## }}}
