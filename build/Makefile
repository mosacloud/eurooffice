PRODUCT_VERSION ?= $(shell cat ../VERSION)
DOCKER_ARGS ?=
PACKAGE_BASE ?= finalubuntu

# Usage examples:
# make build-image
# make build-image DOCKER_ARGS="--no-cache" TARGET="core"
# make rebuild-final
# make docker-target TARGET=core  
# make docker-target TARGET=server

.PHONY: build-image
build-image:
	@docker build -t euro-office/documentserver:latest --build-arg PRODUCT_VERSION=$(PRODUCT_VERSION) --build-arg BUILD_ROOT=/package --target finalubuntu -f ./Dockerfile ../ $(DOCKER_ARGS)

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
	@docker build -t euro-office/documentserver:latest --build-arg PRODUCT_VERSION=$(PRODUCT_VERSION) --build-arg BUILD_ROOT=/package --target $(TARGET) -o $(DEPLOY) -f ./Dockerfile ../ $(DOCKER_ARGS)

.PHONY: build
build:
	@docker build -t euro-office/documentserver:latest --build-arg PRODUCT_VERSION=$(PRODUCT_VERSION) --build-arg BUILD_ROOT=/package --target develop -f ./Dockerfile ../ $(DOCKER_ARGS)

.PHONY: rebuild-final
rebuild-final:
	@docker buildx build -t euro-office/documentserver:latest --build-arg PRODUCT_VERSION=$(PRODUCT_VERSION) --build-arg BUILD_ROOT=/package --target finalubuntu --no-cache-filter finalubuntu -f ./Dockerfile ../ $(DOCKER_ARGS)

.PHONY: run
run: build-image
	@docker run -it --rm -p 8080:80 euro-office/documentserver bash

.PHONY: cache
cache:
	@docker build -t third-party:latest --output type=local,dest=$(NUGET_SOURCE_PATH) --build-arg PRODUCT_VERSION=9.2.1 --build-arg BUILD_ROOT=/package --target third-party-export -f ./Dockerfile ../../ 


desktop: git_hashes.txt
	@docker build --output type=local,dest=./desktopeditors --build-arg PRODUCT_VERSION=9.2.1 --build-arg BUILD_ROOT=/package --target desktop-export -f ./Dockerfile ../../ 

# ---------------------------------------------------------------------------
# Package build targets
# ---------------------------------------------------------------------------

PACKAGES_DIR ?= $(CURDIR)/deploy/packages

.PHONY: packages deb rpm
packages deb rpm: ## Build .deb and .rpm packages into deploy/packages/
	@mkdir -p $(PACKAGES_DIR)
	@DOCKER_BUILDKIT=1 docker build \
		--build-arg PRODUCT_VERSION=$(PRODUCT_VERSION) \
		--build-arg BUILD_ROOT=/package \
		--build-arg PACKAGE_BASE=$(PACKAGE_BASE) \
		--target packages \
		--output type=local,dest=$(PACKAGES_DIR) \
		-f ./Dockerfile ../ \
		$(DOCKER_ARGS)

# ---------------------------------------------------------------------------
# Vagrant VM testing targets
# ---------------------------------------------------------------------------

.PHONY: vagrant-up vagrant-up-ubuntu vagrant-up-debian vagrant-up-rocky vagrant-destroy vagrant-ssh

vagrant-up: ## Bring up all Vagrant test VMs
	@cd vagrant && vagrant up

vagrant-up-ubuntu: ## Bring up Ubuntu 24.04 VM only
	@cd vagrant && vagrant up ubuntu2404

vagrant-up-debian: ## Bring up Debian 12 VM only
	@cd vagrant && vagrant up debian12

vagrant-up-rocky: ## Bring up Rocky Linux 9 VM only
	@cd vagrant && vagrant up rocky9

vagrant-destroy: ## Destroy all Vagrant VMs
	@cd vagrant && vagrant destroy -f

vagrant-ssh: ## SSH into a Vagrant VM (usage: make vagrant-ssh VM=ubuntu2404)
	@cd vagrant && vagrant ssh $(VM)
