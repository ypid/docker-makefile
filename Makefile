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

ARGS      ?= ''
FQDN      ?= 'example.com'
HOST_FQDN ?= $(shell hostname --fqdn)
SHELL     ?= /bin/bash
conf_dir  ?= /etc/docker
DOCKER_BUILD_OPTIONS ?= --no-cache
DOCKER_RUN_OPTIONS ?= --env "TZ=Europe/Berlin"
MKIMAGE_OPTIONS ?= --no-compression
docker_build_dir ?= /var/srv/docker

APT_PROXY_URL ?= $(shell apt-config dump | grep '^Acquire::http::Proxy ' | cut '--delimiter="' --fields 2)

docker_build_debian_additional_programs ?= ,rename,iproute2,iputils-ping,wget
## Needed so often for debugging
docker_build_debian_version ?= jessie

docker_build_postgres_version ?= 9.4

docker_registry_http_secret ?= QMWtyYr7aZc05uKRWlx1ALe5p0v7GFsxKQRxwwl9TyNjDyLMvi1qMf9MBbC5yNK0akmfgygNYprf9WjaNrRdKUJY
## Change this for each docker host!!!

docker_registry_port ?= 5000

image_tor_server        ?= localbuild/tor
image_postgres          ?= localbuild/postgres
image_owncloud          ?= localbuild/owncloud
image_openvpn           ?= localbuild/openvpn
image_seafile           ?= localbuild/seafile
image_nginx_php         ?= localbuild/phpnginx
image_freeswitch        ?= localbuild/freeswitch
image_ejabberd          ?= localbuild/ejabberd
# image_ejabberd          ?= rroemhild/ejabberd
image_chatbot_err       ?= localbuild/chatbot_err
image_chatbot_program_o ?= localbuild/chatbot_program_o
image_chatbot_howie     ?= localbuild/chatbot_howie
image_bittorrent        ?= localbuild/bittorrent
image_registry2         ?= registry:2
image_nginx             ?= nginx
image_mysql             ?= mysql

default:
	@echo See Makefile

snapshots:
	for i in /etc/snapper/configs/*; do snapper --config "`basename $i`" create --description 'Created by Makefile for docker'; done

stop-all:
	docker stop `docker ps --quiet`

push-all: push-debian-base-image push-image-postgres

## https://www.calazan.com/docker-cleanup-commands/
# remove-all-stopped-containers:
#     -docker rm --force=false $(shell docker ps --all --quiet) 2> /dev/null

remove-all-dangling-images:
	-docker rmi --force=false $(shell docker images --quiet --filter 'dangling=true')

# install-images:
#     docker pull jwilder/docker-gen
#     # Updates not needed/wanted

.PHONY: apt-cacher-ng FORCE_MAKE
apt-cacher-ng:
	@(echo "Acquire::http::Proxy \"$(APT_PROXY_URL)\";"; \
	echo "Acquire::https::Proxy \"false\";") > "$@"

build-debian-base-image: apt-cacher-ng
	-$(conf_dir)/docker-makefile/mkimage.sh -t localbuild/debian:$(docker_build_debian_version) $(MKIMAGE_OPTIONS) --dir $(docker_build_dir) debootstrap --include=git,ca-certificates$(docker_build_debian_additional_programs) --variant=minbase $(docker_build_debian_version) "$(APT_PROXY_URL)/http.debian.net/debian"
	docker tag --force debian:$(docker_build_debian_version) debian:latest
	docker tag --force debian:$(docker_build_debian_version) debian:8
	docker tag --force debian:$(docker_build_debian_version) debian:8.1
	rm -rf "$(docker_build_dir)/"*

build-debian-wheezy-i368-base-image: apt-cacher-ng
	-$(conf_dir)/docker-makefile/mkimage.sh -t localbuild/debian_i386:wheezy $(MKIMAGE_OPTIONS) --dir $(docker_build_dir) debootstrap --include=git,ca-certificates,procps --variant=minbase --arch=i386 wheezy "$(APT_PROXY_URL)/http.debian.net/debian"
	docker tag --force localbuild/debian_i386:wheezy debian_i386:wheezy
	docker tag --force localbuild/debian_i386:wheezy debian_i386:7
	rm -rf "$(docker_build_dir)/"*

upgrade-debian-base-image: build-debian-base-image

push-debian-base-image:
	docker tag --force debian:$(docker_build_debian_version) $(HOST_FQDN):$(docker_registry_port)/debian:$(docker_build_debian_version)
	docker push "$(HOST_FQDN):$(docker_registry_port)/debian:$(docker_build_debian_version)"

## build {{{
.PHONY: build-image-tor

build-image-tor:
	-cd "$(conf_dir)/docker-tor" && git pull && docker build $(DOCKER_BUILD_OPTIONS) --tag $(image_tor_server) .

build-image-owncloud:
	-cd "$(conf_dir)/docker-owncloud" && git pull && docker build $(DOCKER_BUILD_OPTIONS) --tag $(image_owncloud) .
	docker tag $(image_owncloud) $(image_owncloud):$(shell date +%F)

build-image-seafile:
	## Used by seafile
	# docker pull phusion/baseimage
	-cd "$(conf_dir)/docker-seafile" && git pull && docker build $(DOCKER_BUILD_OPTIONS) --tag $(image_seafile) .

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
	docker tag $(image_ejabberd) $(image_ejabberd):$(shell date +%F)

build-image-openvpn:
	-cd "$(conf_dir)/docker-openvpn" && git pull && docker build $(DOCKER_BUILD_OPTIONS) --tag $(image_openvpn) .
	docker tag $(image_openvpn) $(image_openvpn):$(shell date +%F)

push-image-openvpn:
	docker tag --force $(image_openvpn) $(HOST_FQDN):$(docker_registry_port)/openvpn
	docker push $(HOST_FQDN):$(docker_registry_port)/openvpn

build-image-postgres:
	-cd "$(conf_dir)/docker-postgres/$(docker_build_postgres_version)" && git pull && docker build $(DOCKER_BUILD_OPTIONS) --tag $(image_postgres) .
	docker tag --force $(image_postgres) $(image_postgres):$(docker_build_postgres_version)
	docker tag --force $(image_postgres) $(image_postgres):$(shell date +%F)

push-image-postgres:
	docker tag --force $(image_postgres) $(HOST_FQDN):$(docker_registry_port)/postgres
	docker tag --force $(image_postgres) $(HOST_FQDN):$(docker_registry_port)/postgres:$(docker_build_postgres_version)
	docker push $(HOST_FQDN):$(docker_registry_port)/postgres
	docker push $(HOST_FQDN):$(docker_registry_port)/postgres:$(docker_build_postgres_version)

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

## docker-registry {{{

## https://docs.docker.com/registry/deploying/
.PHONY: docker-registry
docker-registry:
	-@docker rm --force "$@"
	docker run --detach \
		--name "$@" \
		$(DOCKER_RUN_OPTIONS) \
		--publish $(docker_registry_port):5000 \
		--volume /srv/docker/registry:/var/lib/registry \
		--volume /etc/pki/host/default.crt:/certs/domain.crt:ro \
		--volume /etc/pki/host/default.key:/certs/domain.key:ro \
		--volume /etc/docker/registry:/etc/docker/registry:ro \
		--env REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt \
		--env REGISTRY_HTTP_TLS_KEY=/certs/domain.key \
		--env REGISTRY_HTTP_SECRET=$(docker_registry_http_secret) \
		--env REGISTRY_AUTH=htpasswd \
		--env REGISTRY_AUTH_HTPASSWD_REALM=Registry \
		--env REGISTRY_AUTH_HTPASSWD_PATH=/etc/docker/registry/htpasswd \
		$(image_registry2)
## }}}

## tor server {{{
tor-relay:
	-@docker rm --force "$@"
	docker run --detach \
		--name "$@" \
		$(DOCKER_RUN_OPTIONS) \
		--volume /etc/tor/relay/torrc:/etc/tor/torrc:ro \
		--volume /srv/tor/relay:/var/lib/tor \
		--publish 993:993 \
		--publish 465:465 \
		$(image_tor_server) \
		/usr/bin/tor -f /etc/tor/torrc
		# --volume /srv/tor:/var/lib/tor \

tor-hidden-services:
	-@docker rm --force "$@"
	docker run --detach \
		--name "$@" \
		$(DOCKER_RUN_OPTIONS) \
		--volume /etc/tor/hidden_services/torrc:/etc/tor/torrc:ro \
		--volume /srv/tor/hidden_services:/var/lib/tor \
		--publish-all=false \
		$(image_tor_server) \
		/usr/bin/tor -f /etc/tor/torrc
		# --volume /srv/tor:/var/lib/tor \
## }}}

## Bittorrent {{{
.PHONY: bittorrent
bittorrent:
	-@docker rm --force "$@"
	docker run -it \
		--name "$@" \
		$(DOCKER_RUN_OPTIONS) \
		--env 'VIRTUAL_PATH=staging/bittorrent' \
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
	# -@docker rm --volume --force "$@"
	-@docker rm --force "$@"
	# snapper -c jabber-db create --detach 'Make jabber.'
	docker run --detach \
		--name "$@" \
		$(DOCKER_RUN_OPTIONS) \
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
		$(image_ejabberd)
## }}}

## openvpn {{{
.PHONY: openvpn-gateway-example
openvpn-gateway-example:
	-@docker rm --force "$@"
	docker run --detach \
		--name "$@" \
		$(DOCKER_RUN_OPTIONS) \
		--volume /etc/openvpn/example-gateway:/etc/openvpn:ro \
		--publish 1194:1194/udp \
		--env RUNNING=yes \
		--cap-add=NET_ADMIN \
		$(image_openvpn)
## }}}

## nginx-reverse-reload {{{
.PHONY: nginx-reverse-reload
nginx-reverse-reload:
	docker start nginx-gen
	sleep 3
	docker stop nginx-gen
	docker kill --signal HUP nginx-reverse
## }}}

## owncloud {{{
## See ttps://github.com/jchaney/owncloud for more examples.
.PHONY: owncloud-example
owncloud-example:
	-@docker rm --force "$@"
	docker run --detach \
		--name "$@" \
		$(DOCKER_RUN_OPTIONS) \
		--hostname "$(FQDN)" \
		--link owncloud-db:db \
		--volume '/etc/docker/owncloud-custom/~example:/var/www/~example' \
		--volume /srv/example/owncloud/data:/var/www/owncloud/data \
		--volume /srv/example/owncloud/apps_persistent:/var/www/owncloud/apps_persistent \
		--volume /srv/example/owncloud/config.php:/owncloud/config.php \
		--env 'VIRTUAL_PATH=~example/owncloud' \
		--env 'VIRTUAL_SERVER_TYPE=owncloud' \
		--env 'VIRTUAL_PORT=80' \
		$(image_owncloud)
	$(MAKE) nginx-reverse-reload
# cd /var/www/ && mkdir '~example' && ln -s ../owncloud '~example/'
# Could not get the overwritewebroot to work.
#

# CREATE USER "owncloud_staging" WITH PASSWORD 'l2wVPb5BWYy8x5s5vNEm3JfX76D8IXZ2RWYw5Tjy';
# CREATE DATABASE "owncloud_staging" TEMPLATE template0 ENCODING 'UNICODE';
# ALTER DATABASE "owncloud_staging" OWNER TO "owncloud_staging";
# GRANT ALL PRIVILEGES ON DATABASE "owncloud_staging" TO "owncloud_staging";
owncloud-staging:
	-@docker rm --force "$@"
	docker run --detach \
		--name "$@" \
		$(DOCKER_RUN_OPTIONS) \
		--hostname "$(FQDN)" \
		--link owncloud-db:db \
		--volume '/etc/docker/owncloud-custom/staging:/var/www/staging' \
		--volume /srv/staging/owncloud/data:/var/www/owncloud/data \
		--volume /srv/staging/owncloud/apps_persistent:/var/www/owncloud/apps_persistent \
		--env 'VIRTUAL_PATH=staging/owncloud' \
		--env 'VIRTUAL_SERVER_TYPE=owncloud' \
		--env 'VIRTUAL_PORT=80' \
		$(image_owncloud)
	$(MAKE) nginx-reverse-reload
		r/www/ && mkdir 'staging' && ln -s ../owncloud 'staging/'

## }}}

## seafile {{{

.PHONY: seafile-example-db
seafile-example-db:
	-@docker rm --force "$@"
	snapper -c seafile-example-db create --detach 'Make seafile-example-db.'
	docker run --detach \
		--name "$@" \
		$(DOCKER_RUN_OPTIONS) \
		--env MYSQL_ROOT_PASSWORD=pw \
		--env MYSQL_USER=seafile-user \
		--env MYSQL_DATABASE=seafile-example-db \
		--env MYSQL_PASSWORD=pw2 \
		--volume /srv/example/seafile/db:/var/lib/mysql \
		$(image_mysql)

.PHONY: seafile-example
seafile-example:
	-docker rm --force "$@"
	docker run --detach \
		--name "$@" \
		$(DOCKER_RUN_OPTIONS) \
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
