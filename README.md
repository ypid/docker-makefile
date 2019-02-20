# Manage docker images/containers via GNU make

The repository keeps track of the Makefile I use to manage docker images and containers on various servers.
The Makefile is intended to be included in a per-server Makefile.

# Goals

* All images should be locally build (including the base image)
* All images should be based on Debian Stable.
* A package proxy should be used (defined in the base image)

# Used images

* [kfei/docktorrent][]
* [rroemhild/ejabberd][]
* [lucaspiller/freeswitch][]
* [kylemanna/openvpn][]
* [postgres][]
* [jchaney/owncloud][]
* [jenserat/seafile][]

[kfei/docktorrent]: https://github.com/kfei/docktorrent
[rroemhild/ejabberd]: https://github.com/rroemhild/docker-ejabberd
[lucaspiller/freeswitch]: https://github.com/lucaspiller/docker-freeswitch
[kylemanna/openvpn]: https://github.com/kylemanna/docker-openvpn
[postgres]: https://github.com/docker-library/postgres
[jchaney/owncloud]: https://github.com/jchaney/owncloud
[jenserat/seafile]: https://github.com/JensErat/docker-seafile

# License of the Makefile

[AGPL-3.0-only](https://www.gnu.org/licenses/agpl-3.0.html)

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, version 3 of the
License.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
