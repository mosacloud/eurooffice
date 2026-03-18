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

# ---------------------------------------------------------------------------
# Package build targets
# ---------------------------------------------------------------------------

PACKAGES_DIR ?= $(CURDIR)/deploy/packages

.PHONY: packages deb rpm
packages deb rpm: ## Build .deb and .rpm packages into deploy/packages/
	@mkdir -p $(PACKAGES_DIR)
	@docker buildx build \
		--build-arg PRODUCT_VERSION=$(PRODUCT_VERSION) \
		--build-arg BUILD_ROOT=/package \
		--target packages \
		-o $(PACKAGES_DIR) \
		-f ./Dockerfile ../

.PHONY: test
test: ## Run smoke test against built packages (mounts PACKAGES_DIR into test container)
	@docker buildx build \
		--build-arg PRODUCT_VERSION=$(PRODUCT_VERSION) \
		--build-arg BUILD_ROOT=/package \
		--target test \
		-t ds-test-$(PRODUCT_VERSION) \
		-f ./Dockerfile ../
	@docker run --rm -v $(PACKAGES_DIR):/pkgs ds-test-$(PRODUCT_VERSION)

# Usage examples:
# make build-image
# make rebuild-final
# make docker-target TARGET=core  
# make docker-target TARGET=server

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
