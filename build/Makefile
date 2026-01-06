.PHONY: build-image
build-image:
	@docker build -t euro-office/documentserver --target finalupstream -f ./Dockerfile ../../

DEPLOY ?= deploy/

# Docker target for building specific stages and outputting to deploy directory
.PHONY: docker-target
docker-target:
	@mkdir -p $(DEPLOY)
	@if [ -z "$(TARGET)" ]; then \
		echo "ERROR: TARGET is not set. Usage: make docker-target TARGET=<stage>"; \
		exit 1; \
	fi
	@docker build -t euro-office/documentserver --target $(TARGET) -o $(DEPLOY) -f ./Dockerfile ../../

.PHONY: build
build:
	@docker build --target output -t euro-office/documentserver -o output -f ./Dockerfile ../../

.PHONY: run
run: build-image
	@docker run -it --rm -p 8080:80 euro-office/documentserver bash

.PHONY: report
report: build-image
	@docker run --rm --entrypoint "" euro-office/documentserver bash -c 'find /var/www/onlyoffice -type f -exec sha256sum {} \;' > /tmp/ours.txt
	@docker run --rm --entrypoint "" onlyoffice/documentserver bash -c 'find /var/www/onlyoffice -type f -exec sha256sum {} \;' > /tmp/theirs.txt
	@diff /tmp/ours.txt /tmp/theirs.txt || true
