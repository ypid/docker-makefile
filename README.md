# Automate Docker image building with make

This repository keeps track of the Makefile I use to build Docker (base) images.
The Makefile is intended to be included in a per-host Makefile.

# Goals

* All images should be locally build (including the base image).
* All images should be based on Debian Stable.
* A package proxy should be used. Including it in the base image is the easiest way so that all images based/built from it take advantage of the proxy.

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
