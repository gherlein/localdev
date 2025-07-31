all:
	docker build -t localdev:latest --no-cache --output type=docker .

run:
	docker run --rm -it -v "$(pwd):/workspace" localdev  bash
