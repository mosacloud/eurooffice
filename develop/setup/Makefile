SHELL := /bin/bash

all: web-apps sdkjs core server #core/wasm


CORE_FLAGS    := -DCMAKE_BUILD_TYPE=Debug -DCMAKE_CXX_FLAGS_DEBUG="-g -O0" -DCMAKE_C_FLAGS_DEBUG="-g -O0"
SERVER_FLAGS  :=
SDKJS_FLAGS   :=
WEBAPPS_FLAGS :=

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

## -----------------
## SDKJS BUILD
## -----------------

sdkjs:
	@echo "Building sdkjs with flags $(CFLAGS)"
	cd $(EO_DEV)/sdkjs/build && \
	npm install && \
	BUILD_ROOT=$(EO_ROOT) grunt $(CFLAGS) && \
	/usr/bin/documentserver-generate-allfonts.sh

## -----------------
## CORE BUILD
## -----------------

BUILD_FLAGS     := -DEO_CORE_OUTPUT_DIR=$(EO_ROOT)/server/FileConverter/bin -DEO_CORE_TOOLS_DIR=$(EO_ROOT)/server/tools -DEO_CORE_3RD_PARTY_DIR=/build/3rdParty

define build_core
	@echo "Building $(1) with flags $(CFLAGS)"
	mkdir -p $(1)
	cd $(1) && \
	cmake -GNinja $(BUILD_FLAGS) $(CFLAGS) $(2) && \
	cmake --build .
endef


.PHONY: core

core:
	$(call build_core,/build/core,$(EO_DEV)/core)

core/allfontsgen:
	$(call build_core,/build/allfontsgen,$(EO_DEV)/core/DesktopEditor/AllFontsGen)

core/allthemesgen:
	$(call build_core,/build/allthemesgen,$(EO_DEV)/core/DesktopEditor/allthemesgen)

core/pluginsmanager:
	$(call build_core,/build/pluginsmanager,$(EO_DEV)/core/DesktopEditor/pluginsmanager)

core/x2t:
	$(call build_core,/build/x2t,$(EO_DEV)/core/X2tConverter/build/cmake)

core/docbuilder:
	$(call build_core,/build/docbuilder,$(EO_DEV)/core/DesktopEditor/doctrenderer/app_builder)


## -----------------
## CORE WASM BUILD
## -----------------

define build_wasm
	@echo "Building $(1) with flags $(CFLAGS)"
	mkdir -p $(1)
	cd $(1) && \
	source /opt/emsdk/emsdk_env.sh && \
	emcmake cmake -DEO_CORE_3RD_PARTY_DIR=/build/wasm/3rdParty -DEO_CORE_OUTPUT_DIR=$(2) $(3) && \
	cmake --build .
endef

build-font:
	$(call build_wasm,/build/wasm/font,$(EO_DEV)/sdkjs/common,$(EO_DEV)/core/DesktopEditor/fontengine/js)

build-spell:
	$(call build_wasm,/build/wasm/spell,$(EO_DEV)/sdkjs/common,$(EO_DEV)/core/Common/3dParty/hunspell)

build-zlib:
	$(call build_wasm,/build/wasm/zlib,$(EO_DEV)/sdkjs/common,$(EO_DEV)/core/OfficeUtils/js)

build-hash:
	$(call build_wasm,/build/wasm/hash,$(EO_DEV)/sdkjs/common,$(EO_DEV)/core/DesktopEditor/xmlsec/src/wasm/hash)

build-draw:
	$(call build_wasm,/build/wasm/draw,$(EO_DEV)/sdkjs/pdf/src,$(EO_DEV)/core/DesktopEditor/graphics/pro/js)

core/wasm/font: build-font
	@$(MAKE) sdkjs

core/wasm/spell: build-spell
	@$(MAKE) sdkjs

core/wasm/zlib: build-zlib
	@$(MAKE) sdkjs

core/wasm/hash: build-hash
	@$(MAKE) sdkjs

core/wasm/draw: build-draw
	@$(MAKE) sdkjs

core/wasm: build-font build-spell build-zlib build-hash build-draw
	@echo "All WASM modules built. Running sdkjs..."
	@$(MAKE) sdkjs

## -----------------
## SERVER BUILD
## -----------------

define build_server
	@echo "Building $(1) with flags $(CFLAGS)"
	cd $(1) && \
	npm install && \
	pkg . -t linux-x64 --node-options="--max_old_space_size=4096" $(CFLAGS) -o $(2) && \
	supervisorctl restart $(3)
endef


server: server/common server/docservice server/converter server/metrics server/adminp

server/common:
	cd $(EO_DEV)/server/Common && \
	npm install && \
	sed "s|\(const buildVersion = \).*|\1'${PRODUCT_VERSION}';|" -i sources/commondefines.js

server/docservice: server/common
	$(call build_server,$(EO_DEV)/server/DocService,${EO_ROOT}/server/DocService/docservice, docservice)

server/converter: server/common
	$(call build_server,$(EO_DEV)/server/FileConverter,${EO_ROOT}/server/FileConverter/converter, converter)

server/metrics: server/common
	$(call build_server,$(EO_DEV)/server/Metrics,${EO_ROOT}/server/Metrics/metrics, metrics)

server/adminp: server/common server/adminp/cli server/adminp/srv

server/adminp/srv: server/common
	$(call build_server,$(EO_DEV)/server/AdminPanel/server,${EO_ROOT}/server/AdminPanel/server/adminpanel, adminpanel)

server/adminp/cli: server/common
	@echo "Building server/adminpanel/client with flags $(CFLAGS)"
	cd $(EO_DEV)/server/AdminPanel/client && \
	npm install && \
	BUILD_ROOT=$(EO_ROOT)/server/AdminPanel/client npm run build $(CFLAGS)