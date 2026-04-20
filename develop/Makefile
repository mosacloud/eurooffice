PRODUCT_VERSION ?= $(shell cat ../VERSION)
export PRODUCT_VERSION

# Host LAN IP so phones/emulators/LAN devices can reach DocumentServer and
# Nextcloud via the desktop's routable address rather than localhost.
ifeq ($(shell uname -s),Darwin)
	DETECTED_HOST_LAN_IP := $(shell ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null)
else
	# 1.1.1.1 is a dummy public target — `ip route get` just asks the kernel
	# which local source IP it would use, without actually sending packets.
	DETECTED_HOST_LAN_IP := $(shell ip route get 1.1.1.1 2>/dev/null | awk '{print $$7; exit}')
endif
HOST_LAN_IP ?= $(DETECTED_HOST_LAN_IP)
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
	@echo "   Host LAN IP:   $(or $(HOST_LAN_IP),<not detected>)"
	@echo "   On IP change:  make refresh-urls"
	@echo ""
	docker compose up -d && docker compose exec eo bash

pull:
	docker compose pull && docker compose up -d && docker compose exec eo bash

build:
	(cd ../build && docker buildx bake develop) && \
	(docker compose up -d) && \
	(docker compose exec eo bash)

# Re-point OnlyOffice URLs and trusted_domains at the current HOST_LAN_IP
# without wiping the stack. Use after your LAN IP changes (new wifi, etc.).
refresh-urls:
	@test -n "$(HOST_LAN_IP)" || { echo "HOST_LAN_IP could not be detected; pass it explicitly: make refresh-urls HOST_LAN_IP=1.2.3.4"; exit 1; }
	docker compose exec -u www-data nextcloud ./occ config:app:set onlyoffice DocumentServerUrl --value="http://$(HOST_LAN_IP):8080/"
	docker compose exec -u www-data nextcloud ./occ config:system:set trusted_domains 2 --value=$(HOST_LAN_IP)
