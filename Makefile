ARCH := $(shell uname -m)
REGISTRY := ghcr.io
REPO := gherlein
IMAGE_DEV := $(REGISTRY)/$(REPO)/localdev
IMAGE_FULL := $(REGISTRY)/$(REPO)/localfull
TAG := latest
# Override with VERSION=v1.2.3 for semantic versioning
VERSION ?= $(TAG)

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
.PHONY: publish publish-local publish-full publish-full-local publish-all pull pull-full run run-full install install-scripts pre

help:
	@echo "Available targets:"
	@echo ""
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
	@echo "  publish        - Build and push multi-arch localdev (requires GitHub Actions)"
	@echo "  publish-local  - Push current platform localdev build to $(IMAGE_DEV):$(VERSION)"
	@echo "  publish-full   - Build and push multi-arch localfull (requires GitHub Actions)"
	@echo "  publish-full-local - Push current platform localfull build"
	@echo "  publish-all    - Publish both containers (multi-arch, requires GitHub Actions)"
	@echo ""
	@echo "Note: Multi-arch builds use GitHub Actions. For local testing, use publish-local."
	@echo ""
	@echo "Pull targets:"
	@echo "  pull           - Pull localdev from $(IMAGE_DEV):$(VERSION)"
	@echo "  pull-full      - Pull localfull from $(IMAGE_FULL):$(VERSION)"
	@echo ""
	@echo "Run targets:"
	@echo "  run            - Run default container (localdev)"
	@echo "  run-full       - Run full container (localfull)"
	@echo ""
	@echo "Install targets:"
	@echo "  install        - Install launchers from local files (requires repo clone)"
	@echo "  install-scripts - Extract launchers from container image (no clone needed)"
	@echo "  pre            - Install podman (apt)"
	@echo ""
	@echo "Variables:"
	@echo "  VERSION        - Image tag (default: latest). Example: make build VERSION=v1.0.0"
	@echo "                   When VERSION is not 'latest', both VERSION and latest tags are created/pushed"

all: build build-full

build:
	podman build -t $(IMAGE_DEV):$(VERSION) --format docker --memory=16g --build-arg TARGETARCH=${TARGETARCH} --pull .
	@if [ "$(VERSION)" != "latest" ]; then \
		podman tag $(IMAGE_DEV):$(VERSION) $(IMAGE_DEV):latest; \
		echo "Built $(IMAGE_DEV):$(VERSION) and tagged as latest"; \
	else \
		echo "Built $(IMAGE_DEV):$(VERSION)"; \
	fi

build-full:
	podman build -t $(IMAGE_FULL):$(VERSION) --format docker --memory=16g --build-arg TARGETARCH=${TARGETARCH} --pull -f Containerfile.full .
	@if [ "$(VERSION)" != "latest" ]; then \
		podman tag $(IMAGE_FULL):$(VERSION) $(IMAGE_FULL):latest; \
		echo "Built $(IMAGE_FULL):$(VERSION) and tagged as latest"; \
	else \
		echo "Built $(IMAGE_FULL):$(VERSION)"; \
	fi

default: build

full: build-full

no-cache: no-cache-default no-cache-full

no-cache-default:
	podman build -t $(IMAGE_DEV):$(VERSION) --format docker --no-cache --memory=16g --build-arg TARGETARCH=${TARGETARCH} --pull .
	@if [ "$(VERSION)" != "latest" ]; then \
		podman tag $(IMAGE_DEV):$(VERSION) $(IMAGE_DEV):latest; \
		echo "Built $(IMAGE_DEV):$(VERSION) and tagged as latest"; \
	else \
		echo "Built $(IMAGE_DEV):$(VERSION)"; \
	fi

no-cache-full:
	podman build -t $(IMAGE_FULL):$(VERSION) --format docker --no-cache --memory=16g --build-arg TARGETARCH=${TARGETARCH} --pull -f Containerfile.full .
	@if [ "$(VERSION)" != "latest" ]; then \
		podman tag $(IMAGE_FULL):$(VERSION) $(IMAGE_FULL):latest; \
		echo "Built $(IMAGE_FULL):$(VERSION) and tagged as latest"; \
	else \
		echo "Built $(IMAGE_FULL):$(VERSION)"; \
	fi

publish-local: build
	@echo "Publishing current platform $(IMAGE_DEV):$(VERSION)..."
	podman push "$(IMAGE_DEV):$(VERSION)"
	@if [ "$(VERSION)" != "latest" ]; then \
		podman tag "$(IMAGE_DEV):$(VERSION)" "$(IMAGE_DEV):latest"; \
		podman push "$(IMAGE_DEV):latest"; \
		echo "Published $(IMAGE_DEV):$(VERSION) and $(IMAGE_DEV):latest"; \
	else \
		echo "Published $(IMAGE_DEV):$(VERSION)"; \
	fi

publish: build
	@echo "ERROR: Multi-arch builds should use GitHub Actions"
	@echo "See: .github/workflows/publish-multiarch.yml"
	@echo ""
	@echo "To publish just your current platform, use: make publish-local"
	@echo "To trigger GitHub Actions build: git push origin main"
	@exit 1

publish-multiarch-manual: build
	@echo "Building multi-arch manifest for $(IMAGE_DEV):$(VERSION)..."
	@echo "Building amd64 image..."
	podman build --platform=linux/amd64 -t "$(IMAGE_DEV):$(VERSION)-amd64" --format docker --memory=16g --build-arg TARGETARCH=amd64 --pull .
	@echo "Building arm64 image..."
	podman build --platform=linux/arm64 -t "$(IMAGE_DEV):$(VERSION)-arm64" --format docker --memory=16g --build-arg TARGETARCH=arm64 --pull .
	@echo "Pushing architecture-specific images..."
	podman push "$(IMAGE_DEV):$(VERSION)-amd64"
	podman push "$(IMAGE_DEV):$(VERSION)-arm64"
	@echo "Creating multi-arch manifest..."
	podman manifest rm "$(IMAGE_DEV):$(VERSION)" 2>/dev/null || true
	podman manifest create "$(IMAGE_DEV):$(VERSION)"
	podman manifest add "$(IMAGE_DEV):$(VERSION)" "$(IMAGE_DEV):$(VERSION)-amd64"
	podman manifest add "$(IMAGE_DEV):$(VERSION)" "$(IMAGE_DEV):$(VERSION)-arm64"
	podman manifest push "$(IMAGE_DEV):$(VERSION)"
	@if [ "$(VERSION)" != "latest" ]; then \
		echo "Creating multi-arch manifest for latest..."; \
		podman manifest rm "$(IMAGE_DEV):latest" 2>/dev/null || true; \
		podman manifest create "$(IMAGE_DEV):latest"; \
		podman manifest add "$(IMAGE_DEV):latest" "$(IMAGE_DEV):$(VERSION)-amd64"; \
		podman manifest add "$(IMAGE_DEV):latest" "$(IMAGE_DEV):$(VERSION)-arm64"; \
		podman manifest push "$(IMAGE_DEV):latest"; \
		echo "Published $(IMAGE_DEV):$(VERSION) and $(IMAGE_DEV):latest (multi-arch)"; \
	else \
		echo "Published $(IMAGE_DEV):$(VERSION) (multi-arch)"; \
	fi

publish-full-local: build-full
	@echo "Publishing current platform $(IMAGE_FULL):$(VERSION)..."
	podman push "$(IMAGE_FULL):$(VERSION)"
	@if [ "$(VERSION)" != "latest" ]; then \
		podman tag "$(IMAGE_FULL):$(VERSION)" "$(IMAGE_FULL):latest"; \
		podman push "$(IMAGE_FULL):latest"; \
		echo "Published $(IMAGE_FULL):$(VERSION) and $(IMAGE_FULL):latest"; \
	else \
		echo "Published $(IMAGE_FULL):$(VERSION)"; \
	fi

publish-full: build-full
	@echo "ERROR: Multi-arch builds should use GitHub Actions"
	@echo "See: .github/workflows/publish-multiarch.yml"
	@echo ""
	@echo "To publish just your current platform, use: make publish-full-local"
	@echo "To trigger GitHub Actions build: git push origin main"
	@exit 1

publish-full-multiarch-manual: build-full
	@echo "Building multi-arch manifest for $(IMAGE_FULL):$(VERSION)..."
	@echo "Building amd64 image..."
	podman build --platform=linux/amd64 -t "$(IMAGE_FULL):$(VERSION)-amd64" --format docker --memory=16g --build-arg TARGETARCH=amd64 --pull -f Containerfile.full .
	@echo "Building arm64 image..."
	podman build --platform=linux/arm64 -t "$(IMAGE_FULL):$(VERSION)-arm64" --format docker --memory=16g --build-arg TARGETARCH=arm64 --pull -f Containerfile.full .
	@echo "Pushing architecture-specific images..."
	podman push "$(IMAGE_FULL):$(VERSION)-amd64"
	podman push "$(IMAGE_FULL):$(VERSION)-arm64"
	@echo "Creating multi-arch manifest..."
	podman manifest rm "$(IMAGE_FULL):$(VERSION)" 2>/dev/null || true
	podman manifest create "$(IMAGE_FULL):$(VERSION)"
	podman manifest add "$(IMAGE_FULL):$(VERSION)" "$(IMAGE_FULL):$(VERSION)-amd64"
	podman manifest add "$(IMAGE_FULL):$(VERSION)" "$(IMAGE_FULL):$(VERSION)-arm64"
	podman manifest push "$(IMAGE_FULL):$(VERSION)"
	@if [ "$(VERSION)" != "latest" ]; then \
		echo "Creating multi-arch manifest for latest..."; \
		podman manifest rm "$(IMAGE_FULL):latest" 2>/dev/null || true; \
		podman manifest create "$(IMAGE_FULL):latest"; \
		podman manifest add "$(IMAGE_FULL):latest" "$(IMAGE_FULL):$(VERSION)-amd64"; \
		podman manifest add "$(IMAGE_FULL):latest" "$(IMAGE_FULL):$(VERSION)-arm64"; \
		podman manifest push "$(IMAGE_FULL):latest"; \
		echo "Published $(IMAGE_FULL):$(VERSION) and $(IMAGE_FULL):latest (multi-arch)"; \
	else \
		echo "Published $(IMAGE_FULL):$(VERSION) (multi-arch)"; \
	fi

publish-all: publish publish-full

pull:
	@echo "Pulling $(IMAGE_DEV):$(VERSION)..."
	podman pull $(IMAGE_DEV):$(VERSION)
	@echo "Pulled $(IMAGE_DEV):$(VERSION)"

pull-full:
	@echo "Pulling $(IMAGE_FULL):$(VERSION)..."
	podman pull $(IMAGE_FULL):$(VERSION)
	@echo "Pulled $(IMAGE_FULL):$(VERSION)"

run:
	podman run --rm -it -v "$(shell pwd):/workspace" $(IMAGE_DEV):$(VERSION) bash

run-full:
	podman run --rm -it -v "$(shell pwd):/workspace" $(IMAGE_FULL):$(VERSION) bash

pre:
	sudo apt-get -y install podman

install:
	@if podman image exists $(IMAGE_DEV):latest 2>/dev/null; then \
		cp localdev ~/bin && chmod +x ~/bin/localdev && echo "Installed localdev to ~/bin"; \
		cp localdevnet ~/bin && chmod +x ~/bin/localdevnet && echo "Installed localdevnet to ~/bin"; \
	else \
		echo "Warning: $(IMAGE_DEV):latest image not found, skipping localdev/localdevnet install (run 'make build' or 'make pull' first)"; \
	fi
	@if podman image exists $(IMAGE_FULL):latest 2>/dev/null; then \
		cp localfull ~/bin && chmod +x ~/bin/localfull && echo "Installed localfull to ~/bin"; \
	else \
		echo "Warning: $(IMAGE_FULL):latest image not found, skipping localfull install (run 'make build-full' or 'make pull-full' first)"; \
	fi
	@cp localdevpull ~/bin && chmod +x ~/bin/localdevpull && echo "Installed localdevpull to ~/bin"
	@echo ""
	@echo "To update to the latest container images, run: localdevpull"

install-scripts:
	@echo "Extracting launcher scripts from container..."
	@mkdir -p ~/bin
	@podman run --rm -v ~/bin:/output $(IMAGE_DEV):latest sh -c 'cp /opt/localdev/bin/* /output/ && chmod +x /output/*' 2>/dev/null || \
		(echo "Error: Could not extract scripts. Pull the image first: make pull" && exit 1)
	@echo 'Creating localdevpull script...'
	@echo '#!/bin/bash' > ~/bin/localdevpull
	@echo '# Pull the latest localdev container image' >> ~/bin/localdevpull
	@echo '' >> ~/bin/localdevpull
	@echo 'REGISTRY=ghcr.io' >> ~/bin/localdevpull
	@echo 'REPO=gherlein' >> ~/bin/localdevpull
	@echo 'IMAGE_DEV=$${REGISTRY}/$${REPO}/localdev' >> ~/bin/localdevpull
	@echo 'TAG=latest' >> ~/bin/localdevpull
	@echo '' >> ~/bin/localdevpull
	@echo 'if command -v podman >/dev/null 2>&1; then' >> ~/bin/localdevpull
	@echo '    RUNTIME=podman' >> ~/bin/localdevpull
	@echo 'elif command -v docker >/dev/null 2>&1; then' >> ~/bin/localdevpull
	@echo '    RUNTIME=docker' >> ~/bin/localdevpull
	@echo 'else' >> ~/bin/localdevpull
	@echo '    echo "Error: Neither podman nor docker found in PATH" >&2' >> ~/bin/localdevpull
	@echo '    exit 1' >> ~/bin/localdevpull
	@echo 'fi' >> ~/bin/localdevpull
	@echo '' >> ~/bin/localdevpull
	@echo 'echo "Pulling $${IMAGE_DEV}:$${TAG} using $${RUNTIME}..."' >> ~/bin/localdevpull
	@echo '$${RUNTIME} pull $${IMAGE_DEV}:$${TAG}' >> ~/bin/localdevpull
	@chmod +x ~/bin/localdevpull
	@echo "Installed launcher scripts to ~/bin/"
	@echo "  - localdev"
	@echo "  - localdevnet"
	@if podman image exists $(IMAGE_FULL):latest 2>/dev/null; then \
		echo "  - localfull"; \
	fi
	@echo "  - localdevpull"
	@echo ""
	@echo "To update to the latest container images, run: localdevpull"
