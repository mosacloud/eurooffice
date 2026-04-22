PRODUCT_VERSION ?= $(shell cat ../VERSION)
export PRODUCT_VERSION

# Detect host LAN IP for phones/emulators/LAN devices. Used by `make mobile`
# and `make refresh-urls`.
ifeq ($(shell uname -s),Darwin)
	DETECTED_HOST_LAN_IP := $(shell ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null)
else
	# 1.1.1.1 is a dummy public target — `ip route get` just asks the kernel
	# which local source IP it would use, without actually sending packets.
	DETECTED_HOST_LAN_IP := $(shell ip route get 1.1.1.1 2>/dev/null | awk '{print $$7; exit}')
endif

# Empty by default: `make local` runs on localhost (desktop browser + iOS sim).
# `make mobile` sets this so Android emulators and LAN-connected devices can reach the editor.
HOST_LAN_IP ?=
export HOST_LAN_IP

local:
	@echo ""
	@echo "   ███████╗ ██████╗"
	@echo "   ██╔════╝██╔═══██╗"
	@echo "   █████╗  ██║   ██║"
	@echo "   ██╔══╝  ██║   ██║"
	@echo "   ███████╗╚██████╔╝"
	@echo "   ╚══════╝ ╚═════╝"
	@echo ""
	@echo "   Euro-Office Development Environment"
	@echo ""
ifeq ($(HOST_LAN_IP),)
	@echo "   Mode: localhost (desktop browser + iOS sim)"
	@echo "   For Android / physical device testing: make mobile"
else
	@echo "   Mode: mobile / LAN"
	@echo "   Host LAN IP:   $(HOST_LAN_IP)"
	@echo "   On IP change:  make refresh-urls"
endif
	@echo ""
	docker compose up -d
	@$(MAKE) --no-print-directory refresh-urls
	docker compose exec eo bash

# Like `make local`, but injects the detected HOST_LAN_IP so that Nextcloud
# returns a DocumentServerUrl mobile/LAN clients can actually reach.
mobile:
	@HOST_LAN_IP="$(DETECTED_HOST_LAN_IP)" $(MAKE) local

pull:
	docker compose pull && docker compose up -d && docker compose exec eo bash

build:
	(cd ../build && docker buildx bake develop) && \
	(docker compose up -d) && \
	(docker compose exec eo bash)

# Align OnlyOffice URLs and trusted_domains with the current mode.
# - If HOST_LAN_IP is set: mobile/LAN mode (DocumentServerUrl = http://<ip>:8080/, trusted_domains[2] = <ip>).
# - If HOST_LAN_IP is empty: localhost mode (DocumentServerUrl = http://localhost:8080/, trusted_domains[2] cleared).
# Waits for Nextcloud + OnlyOffice to finish installing on first boot, then applies idempotently.
refresh-urls:
	@start=$$(date +%s); \
	  while ! docker compose exec -T eo curl -sf http://localhost/healthcheck >/dev/null 2>&1; do \
	    printf "\rWaiting for document server (%ds)   " $$(($$(date +%s) - start)); \
	    sleep 2; \
	  done; \
	  printf "\rDocument server ready (%ds).          \n" $$(($$(date +%s) - start))
	@start=$$(date +%s); \
	  while ! docker compose exec -T -u www-data nextcloud ./occ config:app:get onlyoffice DocumentServerUrl 2>/dev/null | grep -q "http"; do \
	    printf "\rWaiting for Nextcloud setup (%ds)   " $$(($$(date +%s) - start)); \
	    sleep 2; \
	  done; \
	  printf "\rNextcloud setup ready (%ds).          \n" $$(($$(date +%s) - start))
	@target="$${HOST_LAN_IP:-localhost}"; \
	  echo "Setting DocumentServerUrl to http://$$target:8080/"; \
	  docker compose exec -T -u www-data nextcloud ./occ config:app:set onlyoffice DocumentServerUrl --value="http://$$target:8080/" >/dev/null; \
	  if [ "$$target" = "localhost" ]; then \
	    docker compose exec -T -u www-data nextcloud ./occ config:system:delete trusted_domains 2 >/dev/null 2>&1 || true; \
	  else \
	    docker compose exec -T -u www-data nextcloud ./occ config:system:set trusted_domains 2 --value=$$target >/dev/null; \
	  fi
