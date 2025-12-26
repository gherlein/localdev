ARCH := $(shell uname -m)
#CMD := podman build -t localdev:latest --no-cache --output type=docker --build-arg TARGETARCH=${TARGETARCH} .

# x86
ifeq ($(ARCH),x86_64)
   TARGETARCH := amd64
endif

# Rockchip/embedded
ifeq ($(ARCH),aarch64)
   TARGETARCH := arm64
endif

# MacOS
ifeq ($(ARCH),arm64)
   TARGETARCH := arm64
endif

.PHONY: help all default full no-cache no-cache-default no-cache-full run run-full pre install

help:
	@echo "Available targets:"
	@echo "  all            - Build both containers (localdev + localfull)"
	@echo "  default        - Build localdev container (lightweight, no Java) - DEFAULT"
	@echo "  full           - Build localfull container (Java, all Node versions, Atlassian CLI)"
	@echo "  no-cache       - Rebuild both containers without cache"
	@echo "  no-cache-default - Rebuild default container without cache"
	@echo "  no-cache-full  - Rebuild full container without cache"
	@echo "  run            - Run default container (localdev)"
	@echo "  run-full       - Run full container (localfull)"
	@echo "  install        - Install both launchers to ~/bin"
	@echo "  pre            - Install podman (apt)"

all: default full

default:
	podman build -t localdev:latest --format docker --memory=16g --build-arg TARGETARCH=${TARGETARCH} --pull .

full:
	podman build -t localfull:latest --format docker --memory=16g --build-arg TARGETARCH=${TARGETARCH} --pull -f Dockerfile.full .

no-cache: no-cache-default no-cache-full

no-cache-default:
	podman build -t localdev:latest --format docker --no-cache --memory=16g --build-arg TARGETARCH=${TARGETARCH} --pull .

no-cache-full:
	podman build -t localfull:latest --format docker --no-cache --memory=16g --build-arg TARGETARCH=${TARGETARCH} --pull -f Dockerfile.full .

run:
	podman run --rm -it -v "$(shell pwd):/workspace" localdev bash

run-full:
	podman run --rm -it -v "$(shell pwd):/workspace" localfull bash

pre:
	sudo apt-get -y install podman

install:
	@if podman image exists localdev:latest 2>/dev/null; then \
		cp localdev ~/bin && echo "Installed localdev to ~/bin"; \
	else \
		echo "Warning: localdev:latest image not found, skipping localdev install (run 'make default' first)"; \
	fi
	@if podman image exists localfull:latest 2>/dev/null; then \
		cp localfull ~/bin && echo "Installed localfull to ~/bin"; \
	else \
		echo "Warning: localfull:latest image not found, skipping localfull install (run 'make full' first)"; \
	fi
