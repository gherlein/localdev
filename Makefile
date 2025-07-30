build:
	docker build -t localdev:latest --no-cache .

run:
	docker run --rm -it -v "$(pwd):/workspace" localdev  bash
