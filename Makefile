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

ARGS     ?= ''
FQDN     ?= 'example.com'
SHELL    ?= /bin/bash
conf_dir ?= /etc/docker
DOCKER_BUILD_OPTIONS ?= --no-cache
docker_build_dir ?= /var/srv/docker
docker_build_debian_version ?= jessie
docker_build_debian_additional_programs ?= ,rename,iproute2

image_tor_server        ?= localbuild/tor
image_postgres          ?= localbuild/postgres
image_owncloud          ?= localbuild/owncloud
image_openvpn           ?= localbuild/openvpn
image_seafile           ?= localbuild/seafile
image_nginx_php         ?= localbuild/phpnginx
image_freeswitch        ?= localbuild/freeswitch
image_ejabberd          ?= localbuild/ejabberd
image_chatbot_err       ?= localbuild/chatbot_err
image_chatbot_program_o ?= localbuild/chatbot_program_o
image_chatbot_howie     ?= localbuild/chatbot_howie
image_bittorrent        ?= localbuild/bittorrent

default:
	echo See Makefile

snapshots:
	for i in /etc/snapper/configs/*; do snapper --config "`basename $i`" create --description 'Created by Makefile for docker'; done

stop-all:
	docker stop `docker ps --quiet`

## https://www.calazan.com/docker-cleanup-commands/
remove-all-stopped-containers:
	-docker rm --force=false $(shell docker ps --all --quiet) 2> /dev/null

remove-all-dangling-images:
	-docker rmi --force=false $(shell docker images --quiet --filter 'dangling=true')

# install-images:
#     docker pull jwilder/docker-gen
#     # Updates not needed/wanted

.PHONY: apt-cacher-ng FORCE_MAKE
apt-cacher-ng:
	@(echo "Acquire::http::Proxy \"$(shell apt-config dump | grep '^Acquire::http::Proxy' | cut '--delimiter="' --fields 2)\";"; \
	echo "Acquire::https::Proxy \"false\";") > "$@"

build-debian-base-image: apt-cacher-ng
	-$(conf_dir)/docker-makefile/mkimage.sh -t localbuild/debian:$(docker_build_debian_version) --no-compression --dir $(docker_build_dir) debootstrap --include=git,ca-certificates$(docker_build_debian_additional_programs) --variant=minbase $(docker_build_debian_version) "$(shell apt-config dump | grep '^Acquire::http::Proxy' | cut '--delimiter="' --fields 2)/http.debian.net/debian"
	@image=`docker images | grep 'localbuild/debian\s+$(docker_build_debian_version)' | head --lines 1`; \
	echo $$image; \
	id="`echo $$image | awk '{ print $$3 }'`"; \
	docker tag --force $$id debian:latest; \
	docker tag --force $$id debian:8; \
	docker tag --force $$id debian:8.1; \
	docker tag --force $$id debian:$(docker_build_debian_version)
	rm -rf "$(docker_build_dir)/"*

upgrade-debian-base-image: build-debian-base-image

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
		--volume /etc/tor/relay/torrc:/etc/tor/torrc \
		--volume /srv/tor:/var/lib/tor \
		--env "TZ=Europe/Berlin" \
		--publish 993:993 \
		--publish 465:465 \
		$(image_tor_server) \
		/usr/bin/tor -f /etc/tor/torrc
		# --volume /srv/tor:/var/lib/tor \

tor-hidden-services:
	-@docker rm -f "$@"
	docker run -d \
		--name "$@" \
		--volume /etc/tor/hidden_services:/etc/tor \
		--volume /srv/tor_hidden_service:/var/lib/tor \
		--publish-all=false \
		--env "TZ=Europe/Berlin" \
		$(image_tor_server) \
		/usr/bin/tor -f /etc/tor/torrc
		# --volume /srv/tor:/var/lib/tor \
## }}}

## Bittorrent {{{
.PHONY: bittorrent
bittorrent:
	-@docker rm -f "$@"
	docker run -it \
		--name "$@" \
		--env "TZ=Europe/Berlin" \
		--env 'VIRTUAL_PATH=~user_a/bittorrent' \
		--env 'VIRTUAL_SERVER_TYPE=rutorrent' \
		--publish 45566:45566 \
		--publish 9527:9527/udp \
		--volume /srv/bittorrent:/rtorrent \
		--volume /etc/rtorrent/htpasswd:/etc/nginx/htpasswd:ro \
		--volume /etc/rtorrent/nginx:/etc/nginx/sites-available/default:ro \
		--env UPLOAD_RATE=500 \
		$(image_bittorrent)
		# --volume /etc/rtorrent/rtorrent.rc:/root/.rtorrent.rc \
		# --publish 801:80 \
## }}}

## ejabberd {{{
ejabberd-example:
	# -@docker rm --volume -f "$@"
	-@docker rm -f "$@"
	# snapper -c jabber-db create -d 'Make jabber.'
	docker run -d \
		--name "$@" \
		--publish 5222:5222 \
		--publish 5269:5269 \
		--publish 5280:5280 \
		--volume /etc/ssl/$(FQDN).pem:/opt/ejabberd/ssl/host.pem:ro \
		--volume /etc/ssl/$(FQDN).pem:/opt/ejabberd/ssl/$(FQDN).pem:ro \
		--volume /etc/ejabberd/ejabberd.yml.tpl:/opt/ejabberd/conf/ejabberd.yml.tpl:ro \
		--volume /srv/jabber/db:/opt/ejabberd/database/ejabberd \
		--hostname '$(FQDN)' \
		--env "ERLANG_NODE=ejabberd" \
		--env "XMPP_DOMAIN=$(FQDN)" \
		--env "EJABBERD_ADMIN=admin@$(FQDN) admin2@$(FQDN)" \
		--env "TZ=Europe/Berlin" \
		$(image_ejabberd)
## }}}

## openvpn {{{
.PHONY: openvpn-gateway-example
openvpn-gateway-example:
	-@docker rm -f "$@"
	docker run -d \
		--name "$@" \
		--volume /etc/openvpn/example-gateway:/etc/openvpn:ro \
		--publish 1194:1194/udp \
		--env RUNNING=yes \
		--env "TZ=Europe/Berlin" \
		--cap-add=NET_ADMIN \
		$(image_openvpn)
## }}}

## nginx-reverse-reload {{{
.PHONY: nginx-reverse-reload
nginx-reverse-reload: nginx-gen
	docker start nginx-gen
	docker stop nginx-gen
	# docker restart nginx-reverse
	docker kill --signal HUP nginx-reverse
## }}}

## owncloud {{{
.PHONY: owncloud-example
owncloud-example:
	-@docker rm -f "$@"
	docker run -d \
		--name "$@" \
		--hostname "$(FQDN)" \
		--link owncloud-db:db \
		--volume /srv/example/owncloud/data:/var/www/owncloud/data \
		--volume /srv/example/owncloud/apps_persistent:/var/www/owncloud/apps_persistent \
		--volume /srv/example/owncloud/config.php:/owncloud/config.php \
		--env 'VIRTUAL_PATH=~example/owncloud' \
		--env 'VIRTUAL_SERVER_TYPE=owncloud' \
		--env 'VIRTUAL_PORT=80' \
		--env "TZ=Europe/Berlin" \
		$(image_owncloud)
	$(MAKE) nginx-reverse-reload
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

## seafile {{{

.PHONY: seafile-example-db
seafile-example-db:
	-@docker rm -f "$@"
	snapper -c seafile-example-db create -d 'Make seafile-example-db.'
	docker run -d \
		--name "$@" \
		--env MYSQL_ROOT_PASSWORD=pw \
		--env MYSQL_USER=seafile-user \
		--env MYSQL_DATABASE=seafile-example-db \
		--env MYSQL_PASSWORD=pw2 \
		--env "TZ=Europe/Berlin" \
		--volume /srv/example/seafile/db:/var/lib/mysql \
		mysql

.PHONY: seafile-example
seafile-example:
	-docker rm -f "$@"
	docker run -d \
		--name "$@" \
		--env "TZ=Europe/Berlin" \
		--publish 10002:10002 \
		--publish 12002:12002 \
		--volume "/srv/example/seafile/data:/opt/seafile" \
		--link seafile-example-db:db \
		--env "DB_ENV_MYSQL_USER=overwrite" \
		--env "DB_ENV_MYSQL_PASSWORD=overwrite" \
		--env "DB_ENV_MYSQL_DATABASE=overwrite" \
		--env "DB_ENV_MYSQL_ROOT_PASSWORD=overwrite" \
		--env 'VIRTUAL_PATH=example' \
		--env 'VIRTUAL_PORT=8000' \
		--env 'VIRTUAL_SERVER_TYPE=seafile' \
		--env fastcgi=true \
		--env autostart=true \
		$(image_seafile)
	$(MAKE) nginx-reverse-reload
