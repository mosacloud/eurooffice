PRODUCT_VERSION ?= $(shell cat ../VERSION)
export PRODUCT_VERSION

local:
	docker compose up -d && docker compose exec eo bash

pull:
	docker compose pull && docker compose up -d && docker compose exec eo bash

build:
	(cd ../build && docker buildx bake develop) && \
	(docker compose up -d) && \
	(docker compose exec eo bash)
