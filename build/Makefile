PRODUCT_VERSION ?= $(shell cat ../VERSION)

.PHONY: build-image
build-image:
	@docker build -t euro-office/documentserver:latest --build-arg PRODUCT_VERSION=$(PRODUCT_VERSION) --build-arg BUILD_ROOT=/package --target finalubuntu -f ./Dockerfile ../

DEPLOY ?= deploy/
# Docker target for building specific stages and outputting to deploy directory
.PHONY: docker-target
docker-target:
	@mkdir -p $(DEPLOY)
	@if [ -z "$(TARGET)" ]; then \
		echo "ERROR: TARGET is not set. Usage: make docker-target TARGET=<stage>"; \
		exit 1; \
	fi
	@docker build -t euro-office/documentserver:latest --build-arg PRODUCT_VERSION=$(PRODUCT_VERSION) --build-arg BUILD_ROOT=/package --target $(TARGET) -o $(DEPLOY) -f ./Dockerfile ../

.PHONY: build
build:
	@docker build -t euro-office/documentserver:latest --build-arg PRODUCT_VERSION=$(PRODUCT_VERSION) --build-arg BUILD_ROOT=/package --target develop -f ./Dockerfile ../

.PHONY: rebuild-final
rebuild-final:
	@docker buildx build -t euro-office/documentserver:latest --build-arg PRODUCT_VERSION=$(PRODUCT_VERSION) --build-arg BUILD_ROOT=/package --target finalubuntu --no-cache-filter finalubuntu -f ./Dockerfile ../

.PHONY: run
run: build-image
	@docker run -it --rm -p 8080:80 euro-office/documentserver bash

# Usage examples:
# make build-image
# make rebuild-final
# make docker-target TARGET=core  
# make docker-target TARGET=server
