ARCH := $(shell uname -m)
REGISTRY := ghcr.io
REPO := gherlein
IMAGE_DEV := $(REGISTRY)/$(REPO)/localdev
IMAGE_FULL := $(REGISTRY)/$(REPO)/localfull
TAG := latest

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

.PHONY: help all default full build build-full no-cache no-cache-default no-cache-full
.PHONY: publish publish-full publish-all pull pull-full run run-full install pre

help:
	@echo "Available targets:"
	@echo "Build targets:"
	@echo "  build          - Build localdev container (lightweight, no Java)"
	@echo "  build-full     - Build localfull container (Java, all Node versions, Atlassian CLI)"
	@echo "  all            - Build both containers (localdev + localfull)"
	@echo "  default        - Alias for 'build' (backwards compatibility)"
	@echo "  full           - Alias for 'build-full' (backwards compatibility)"
	@echo "  no-cache       - Rebuild both containers without cache"
	@echo "  no-cache-default - Rebuild default container without cache"
	@echo "  no-cache-full  - Rebuild full container without cache"
	@echo ""
	@echo "Publish targets:"
	@echo "  publish        - Tag and push localdev to $(IMAGE_DEV):$(TAG)"
	@echo "  publish-full   - Tag and push localfull to $(IMAGE_FULL):$(TAG)"
	@echo "  publish-all    - Publish both containers"
	@echo ""
	@echo "Pull targets:"
	@echo "  pull           - Pull localdev from $(IMAGE_DEV):$(TAG)"
	@echo "  pull-full      - Pull localfull from $(IMAGE_FULL):$(TAG)"
	@echo ""
	@echo "Run targets:"
	@echo "  run            - Run default container (localdev)"
	@echo "  run-full       - Run full container (localfull)"
	@echo "  install        - Install all launchers to ~/bin"
	@echo "  pre            - Install podman (apt)"

all: build build-full

build:
	podman build -t $(IMAGE_DEV):$(TAG) --format docker --memory=16g --build-arg TARGETARCH=${TARGETARCH} --pull .
	@echo "Built $(IMAGE_DEV):$(TAG)"

build-full:
	podman build -t $(IMAGE_FULL):$(TAG) --format docker --memory=16g --build-arg TARGETARCH=${TARGETARCH} --pull -f Containerfile.full .
	@echo "Built $(IMAGE_FULL):$(TAG)"

default: build

full: build-full

no-cache: no-cache-default no-cache-full

no-cache-default:
	podman build -t $(IMAGE_DEV):$(TAG) --format docker --no-cache --memory=16g --build-arg TARGETARCH=${TARGETARCH} --pull .
	@echo "Built $(IMAGE_DEV):$(TAG)"

no-cache-full:
	podman build -t $(IMAGE_FULL):$(TAG) --format docker --no-cache --memory=16g --build-arg TARGETARCH=${TARGETARCH} --pull -f Containerfile.full .
	@echo "Built $(IMAGE_FULL):$(TAG)"

publish: build
	@echo "Publishing $(IMAGE_DEV):$(TAG)..."
	podman push $(IMAGE_DEV):$(TAG)
	@echo "Published $(IMAGE_DEV):$(TAG)"

publish-full: build-full
	@echo "Publishing $(IMAGE_FULL):$(TAG)..."
	podman push $(IMAGE_FULL):$(TAG)
	@echo "Published $(IMAGE_FULL):$(TAG)"

publish-all: publish publish-full

pull:
	@echo "Pulling $(IMAGE_DEV):$(TAG)..."
	podman pull $(IMAGE_DEV):$(TAG)
	@echo "Pulled $(IMAGE_DEV):$(TAG)"

pull-full:
	@echo "Pulling $(IMAGE_FULL):$(TAG)..."
	podman pull $(IMAGE_FULL):$(TAG)
	@echo "Pulled $(IMAGE_FULL):$(TAG)"

run:
	podman run --rm -it -v "$(shell pwd):/workspace" $(IMAGE_DEV):$(TAG) bash

run-full:
	podman run --rm -it -v "$(shell pwd):/workspace" $(IMAGE_FULL):$(TAG) bash

pre:
	sudo apt-get -y install podman

install:
	@if podman image exists $(IMAGE_DEV):$(TAG) 2>/dev/null; then \
		cp localdev ~/bin && chmod +x ~/bin/localdev && echo "Installed localdev to ~/bin"; \
		cp localdevnet ~/bin && chmod +x ~/bin/localdevnet && echo "Installed localdevnet to ~/bin"; \
	else \
		echo "Warning: $(IMAGE_DEV):$(TAG) image not found, skipping localdev/localdevnet install (run 'make build' or 'make pull' first)"; \
	fi
	@if podman image exists $(IMAGE_FULL):$(TAG) 2>/dev/null; then \
		cp localfull ~/bin && chmod +x ~/bin/localfull && echo "Installed localfull to ~/bin"; \
	else \
		echo "Warning: $(IMAGE_FULL):$(TAG) image not found, skipping localfull install (run 'make build-full' or 'make pull-full' first)"; \
	fi
