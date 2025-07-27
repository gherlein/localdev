build:
	docker build -t localdev:latest --output type=docker .

run:
	docker run --rm -it -v "$(pwd):/workspace" localdev  bash
