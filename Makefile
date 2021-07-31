.DEFAULT_GOAL := run
SHELL := /bin/bash
COMMIT_SHA = $(shell git rev-parse HEAD)

.PHONY: help
## help: prints this help message
help:
	@echo "Usage:"
	@sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' |  sed -e 's/^/ /'

.PHONY: run
## run: runs the Hugo server
run:
	hugo server -D -E -F

.PHONY: build
## build: generates the blog content
build:
	hugo --minify
