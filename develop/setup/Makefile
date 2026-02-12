all: web-apps sdkjs core server #core/wasm


CORE_FLAGS    := -DCMAKE_BUILD_TYPE=Debug -DCMAKE_CXX_FLAGS_DEBUG="-g -O0" -DCMAKE_C_FLAGS_DEBUG="-g -O0"
SERVER_FLAGS  :=
SDKJS_FLAGS   :=
CC_PLATFORM   ?= $(shell $(EO_DEV)/sdkjs/build/node_modules/google-closure-compiler-linux/compiler --version >/dev/null 2>&1 && echo "native,java" || echo "java")
WEBAPPS_FLAGS :=

CHECK_WEBAPPS_DEPS = @test -d $(EO_DEV)/web-apps/build/node_modules || { echo "Run 'make web-apps' first to install dependencies"; exit 1; }

# Dev-friendly cache flush: regenerate nginx cache tag and reload, without
# the production-only api.js.tpl copy and ds:ds chown from the upstream script.
define FLUSH_CACHE
	@HASH=$$(date +'%Y.%m.%d-%H%M' | openssl md5 | awk '{print $$2}'); \
	echo "set \$$cache_tag \"$$HASH\";" > /etc/nginx/includes/ds-cache.conf; \
	service nginx reload
endef

sdkjs:    DEBUG_FLAGS = $(SDKJS_FLAGS)


web-apps: DEBUG_FLAGS = $(WEBAPPS_FLAGS)

core/%:   DEBUG_FLAGS = $(CORE_FLAGS)
core:     DEBUG_FLAGS = $(CORE_FLAGS)

server/%: DEBUG_FLAGS = $(SERVER_FLAGS)
server:   DEBUG_FLAGS = $(SERVER_FLAGS)


# The flags will only be populated if DEBUG=1 is passed
ifeq ($(DEBUG), 1)
    CFLAGS += $(DEBUG_FLAGS)
endif


## -----------------
## WEB-APPS BUILD
## -----------------

web-apps:
	@echo "Building web-apps with flags $(CFLAGS)"
	cd $(EO_DEV)/web-apps/build && \
	npm ci && \
	BUILD_ROOT=$(EO_ROOT) grunt $(CFLAGS)
	$(FLUSH_CACHE)

web-apps-dev:
	$(CHECK_WEBAPPS_DEPS)
	cd $(EO_DEV)/web-apps/build && \
	THEME=nextcloud BUILD_ROOT=$(EO_ROOT) grunt --skip-imagemin --skip-babel $(CFLAGS)
	$(FLUSH_CACHE)

## -----------------
## SDKJS BUILD
## -----------------

sdkjs:
	@echo "Building sdkjs with flags $(CFLAGS)"
	cd $(EO_DEV)/sdkjs/build && \
	npm install && \
	CC_PLATFORM=$(CC_PLATFORM) BUILD_ROOT=$(EO_ROOT) grunt $(CFLAGS) && \
	/usr/bin/documentserver-generate-allfonts.sh

## -----------------
## CORE BUILD
## -----------------

BUILD_FLAGS     := -DEO_CORE_OUTPUT_DIR=$(EO_ROOT)/server/FileConverter/bin -DEO_CORE_TOOLS_DIR=$(EO_ROOT)/server/tools -DEO_CORE_3RD_PARTY_DIR=/build/3rdParty

.PHONY: core

core:
	@echo "Building core with flags $(CFLAGS)"
	mkdir -p /build/core
	cd /build/core && \
	cmake -GNinja $(BUILD_FLAGS) $(CFLAGS) $(EO_DEV)/core && \
	cmake --build .

core/allfontsgen:
	@echo "Building core/allfontsgen with flags $(CFLAGS)"
	mkdir -p /build/allfontsgen
	cd /build/allfontsgen && \
	cmake -GNinja $(BUILD_FLAGS) $(CFLAGS) $(EO_DEV)/core/DesktopEditor/AllFontsGen && \
	cmake --build .

core/allthemesgen:
	@echo "Building core/allthemesgen with flags $(CFLAGS)"
	mkdir -p /build/allthemesgen
	cd /build/allthemesgen && \
	cmake -GNinja $(BUILD_FLAGS) $(CFLAGS) $(EO_DEV)/core/DesktopEditor/allthemesgen && \
	cmake --build .

core/pluginsmanager:
	@echo "Building core/pluginsmanager with flags $(CFLAGS)"
	mkdir -p /build/pluginsmanager
	cd /build/pluginsmanager && \
	cmake -GNinja $(BUILD_FLAGS) $(CFLAGS) $(EO_DEV)/core/DesktopEditor/pluginsmanager && \
	cmake --build .

core/x2t:
	@echo "Building core/x2t with flags $(CFLAGS)"
	mkdir -p /build/x2t
	cd /build/x2t && \
	cmake -GNinja $(BUILD_FLAGS) $(CFLAGS) $(EO_DEV)/core/X2tConverter/build/cmake && \
	cmake --build .

core/docbuilder:
	@echo "Building core/docbuilder with flags $(CFLAGS)"
	mkdir -p /build/docbuilder
	cd /build/docbuilder && \
	cmake -GNinja $(BUILD_FLAGS) $(CFLAGS) $(EO_DEV)/core/DesktopEditor/doctrenderer/app_builder && \
	cmake --build .

core/wasm:
	@echo "Error: this option is not supported yet"
	@exit 1

## -----------------
## SERVER BUILD
## -----------------

server: server/common server/docservice server/converter server/metrics server/adminp

server/common:
	cd $(EO_DEV)/server/Common && \
	npm install && \
	sed "s|\(const buildVersion = \).*|\1'${PRODUCT_VERSION}';|" -i sources/commondefines.js

server/docservice: server/common
	@echo "Building server/docservice with flags $(CFLAGS)"
	cd $(EO_DEV)/server/DocService && \
	npm install && \
	pkg . -t linux-x64 --node-options="--max_old_space_size=4096" $(CFLAGS) -o ${EO_ROOT}/server/DocService/docservice && \
	supervisorctl restart docservice

server/converter: server/common
	@echo "Building server/converter with flags $(CFLAGS)"
	cd $(EO_DEV)/server/FileConverter && \
	npm install && \
	pkg . -t linux-x64 --node-options="--max_old_space_size=4096" $(CFLAGS) -o ${EO_ROOT}/server/FileConverter/converter && \
	supervisorctl restart converter

server/metrics: server/common
	@echo "Building server/metrics with flags $(CFLAGS)"
	cd $(EO_DEV)/server/Metrics && \
	npm install && \
	pkg . -t linux-x64 --node-options="--max_old_space_size=4096" $(CFLAGS) -o ${EO_ROOT}/server/Metrics/metrics && \
	supervisorctl restart metrics

server/adminp: server/common server/adminp/cli server/adminp/srv

server/adminp/srv: server/common
	@echo "Building server/adminpanel/server with flags $(CFLAGS)"
	cd $(EO_DEV)/server/AdminPanel/server && \
	npm install && \
	pkg . -t linux-x64 --node-options="--max_old_space_size=4096" $(CFLAGS) -o ${EO_ROOT}/server/AdminPanel/server/adminpanel && \
	supervisorctl restart adminpanel

server/adminp/cli: server/common
	@echo "Building server/adminpanel/client with flags $(CFLAGS)"
	cd $(EO_DEV)/server/AdminPanel/client && \
	npm install && \
	BUILD_ROOT=$(EO_ROOT)/server/AdminPanel/client npm run build $(CFLAGS)