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
	cp localdev ~/bin
	cp localdevf ~/bin
