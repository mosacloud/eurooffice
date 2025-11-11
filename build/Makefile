.PHONY: build-image
build-image:
	@docker build -t euro-office/documentserver --target final -f ./Dockerfile ../../

.PHONY: docker-target
docker-target:
	@docker build -t euro-office/documentserver --target $(TARGET) -f ./Dockerfile ../../

.PHONY: build
build:
	@docker build --target output -t euro-office/documentserver -o output -f ./Dockerfile ../../

.PHONY: report
report: build-image
	@docker run --rm --entrypoint "" euro-office/documentserver bash -c 'find /var/www/onlyoffice -type f -exec sha256sum {} \;' > /tmp/ours.txt
	@docker run --rm --entrypoint "" onlyoffice/documentserver bash -c 'find /var/www/onlyoffice -type f -exec sha256sum {} \;' > /tmp/theirs.txt
	@diff /tmp/ours.txt /tmp/theirs.txt || true
