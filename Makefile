build:
	docker build -t localdev:latest .

run:
	docker run --rm -it -v "$(pwd):/workspace" localdev  bash
