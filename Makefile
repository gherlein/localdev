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

.PHONY: help all full fast no-cache no-cache-full no-cache-fast run run-fast pre install

help:
	@echo "Available targets:"
	@echo "  all            - Build both containers (full + fast)"
	@echo "  full           - Build full localdev container (Java, all Node versions)"
	@echo "  fast           - Build fast localdevf container (no Java, Node LTS only)"
	@echo "  no-cache       - Rebuild both containers without cache"
	@echo "  no-cache-full  - Rebuild full container without cache"
	@echo "  no-cache-fast  - Rebuild fast container without cache"
	@echo "  run            - Run full container"
	@echo "  run-fast       - Run fast container"
	@echo "  install        - Install both launchers to ~/bin"
	@echo "  pre            - Install podman (apt)"

all: full fast

full:
	podman build -t localdev:latest --format docker --memory=16g --build-arg TARGETARCH=${TARGETARCH} --pull .

fast:
	podman build -t localdevf:latest --format docker --memory=16g --build-arg TARGETARCH=${TARGETARCH} --pull -f Dockerfile.fast .

no-cache: no-cache-full no-cache-fast

no-cache-full:
	podman build -t localdev:latest --format docker --no-cache --memory=16g --build-arg TARGETARCH=${TARGETARCH} --pull .

no-cache-fast:
	podman build -t localdevf:latest --format docker --no-cache --memory=16g --build-arg TARGETARCH=${TARGETARCH} --pull -f Dockerfile.fast .

run:
	podman run --rm -it -v "$(shell pwd):/workspace" localdev bash

run-fast:
	podman run --rm -it -v "$(shell pwd):/workspace" localdevf bash

pre:
	sudo apt-get -y install podman

install:
	@if podman image exists localdev:latest 2>/dev/null; then \
		cp localdev ~/bin && echo "Installed localdev to ~/bin"; \
	else \
		echo "Warning: localdev:latest image not found, skipping localdev install (run 'make full' first)"; \
	fi
	@if podman image exists localdevf:latest 2>/dev/null; then \
		cp localdevf ~/bin && echo "Installed localdevf to ~/bin"; \
	else \
		echo "Warning: localdevf:latest image not found, skipping localdevf install (run 'make fast' first)"; \
	fi
