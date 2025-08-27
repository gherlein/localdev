ARCH := $(shell uname -m)

ifeq ($(ARCH),x86_64)
   TARGETARCH := amd64
   CMD := docker build -t localdev:latest --no-cache --output type=docker --build-arg TARGETARCH=${TARGETARCH} .
endif

ifeq ($(ARCH),aarch64)
   TARGETARCH := arm64
   CMD := podman build -t localdev:latest --build-arg TARGETARCH=${TARGETARCH} --pull .
endif

all:
	${CMD}

run:
	docker run --rm -it -v "$(pwd):/workspace" localdev  bash
