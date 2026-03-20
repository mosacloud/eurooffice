.PHONY: build-image
build-image:
	@docker build -t euro-office/documentserver:latest --build-arg PRODUCT_VERSION=9.2.1 --build-arg BUILD_ROOT=/package --target finalubuntu -f ./Dockerfile ../../

DEPLOY ?= deploy/

git_hashes.txt:
	@cd ../.. && \
	: > git_hashes.txt && \
	for dir in $$(find . -mindepth 1 -maxdepth 1 -type d); do \
		[ -d "$$dir/.git" ] && \
		echo "$$dir $$(git -C $$dir rev-parse HEAD)" >> git_hashes.txt; \
	done

# Docker target for building specific stages and outputting to deploy directory
.PHONY: docker-target
docker-target:
	@mkdir -p $(DEPLOY)
	@if [ -z "$(TARGET)" ]; then \
		echo "ERROR: TARGET is not set. Usage: make docker-target TARGET=<stage>"; \
		exit 1; \
	fi
	@docker build -t euro-office/documentserver:latest --build-arg PRODUCT_VERSION=9.2.1 --build-arg BUILD_ROOT=/package  --target $(TARGET) -o $(DEPLOY) -f ./Dockerfile ../../

.PHONY: build
build:
	@docker build -t euro-office/documentserver:latest --build-arg PRODUCT_VERSION=9.2.1 --build-arg BUILD_ROOT=/package --target develop -f ./Dockerfile ../../

.PHONY: run
run: build-image
	@docker run -it --rm -p 8080:80 euro-office/documentserver bash

.PHONY: cache
cache:
	@docker build -t third-party:latest --output type=local,dest=$(NUGET_SOURCE_PATH) --build-arg PRODUCT_VERSION=9.2.1 --build-arg BUILD_ROOT=/package --target third-party-export -f ./Dockerfile ../../ 


desktop: git_hashes.txt
	@docker build --output type=local,dest=./desktopeditors --build-arg PRODUCT_VERSION=9.2.1 --build-arg BUILD_ROOT=/package --target desktop-export -f ./Dockerfile ../../ 