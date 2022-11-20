# Automate Docker image building with make

This repository keeps track of the Makefile I use to build Docker (base) images.
The Makefile is intended to be included in a per-host Makefile.

## Goals

* All images should be locally build (including the base image).
* All images should be based on Debian Stable.
* A package proxy should be used. Including it in the base image is the easiest way so that all images based/built from it take advantage of the proxy.
