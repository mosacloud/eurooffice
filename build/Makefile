TARGET_CPU ?= x64

.PHONY: build-image
build-image:
	@docker build -t euro-office/documentserver:latest --build-arg PRODUCT_VERSION=9.2.1 --build-arg BUILD_ROOT=/package --build-arg TARGETCPU=$(TARGET_CPU) --target finalubuntu -f ./Dockerfile ../

DEPLOY ?= deploy/

# Docker target for building specific stages and outputting to deploy directory
.PHONY: docker-target
docker-target:
	@mkdir -p $(DEPLOY)
	@if [ -z "$(TARGET)" ]; then \
		echo "ERROR: TARGET is not set. Usage: make docker-target TARGET=<stage>"; \
		exit 1; \
	fi
	@docker build -t euro-office/documentserver:latest --build-arg PRODUCT_VERSION=9.2.1 --build-arg BUILD_ROOT=/package --build-arg TARGET_CPU=$(TARGET_CPU) --target $(TARGET) -o $(DEPLOY) -f ./Dockerfile ../

.PHONY: build
build:
	@docker build -t euro-office/documentserver:latest --build-arg PRODUCT_VERSION=9.2.1 --build-arg BUILD_ROOT=/package --build-arg TARGET_CPU=$(TARGET_CPU) --target develop -f ./Dockerfile ../

.PHONY: run
run: build-image
	@docker run -it --rm -p 8080:80 euro-office/documentserver bash

# Usage examples:
# make build-image              # Build for x64 (default)
# make build-image TARGET_CPU=arm64  # Build for ARM64
# make docker-target TARGET=core        # Build core stage
# make docker-target TARGET=server TARGET_CPU=arm64    # Build server stage for ARM64
