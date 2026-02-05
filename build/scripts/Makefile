all: web-apps sdkjs core server #core/wasm

## -----------------
## WEB-APPS BUILD
## -----------------

web-apps:
	@echo "Building web-apps..."
	cd $(EO_DEV)/web-apps/build && \
	npm ci && \
	BUILD_ROOT=$(EO_ROOT) grunt

## -----------------
## SDKJS BUILD
## -----------------

sdkjs:
	@echo "Building sdkjs..."
	cd $(EO_DEV)/sdkjs/build && \
	npm install && \
	BUILD_ROOT=$(EO_ROOT) grunt && \
	/usr/bin/documentserver-generate-allfonts.sh

## -----------------
## CORE BUILD
## -----------------

BUILD_FLAGS     := -DEO_CORE_OUTPUT_DIR=$(EO_ROOT)/server/FileConverter/bin -DEO_CORE_TOOLS_DIR=$(EO_ROOT)/server/tools -DEO_CORE_3RD_PARTY_DIR=/build/3rdParty

.PHONY: core

core:
	@echo "Building core..."
	mkdir -p /build/core
	cd /build/core && \
	cmake -GNinja $(BUILD_FLAGS) $(EO_DEV)/core && \
	cmake --build .

core/allfontsgen:
	@echo "Building core/allfontsgen..."
	mkdir -p /build/allfontsgen
	cd /build/allfontsgen && \
	cmake -GNinja $(BUILD_FLAGS) $(EO_DEV)/core/DesktopEditor/AllFontsGen && \
	cmake --build .

core/allthemesgen:
	@echo "Building core/allthemesgen..."
	mkdir -p /build/allthemesgen
	cd /build/allthemesgen && \
	cmake -GNinja $(BUILD_FLAGS) $(EO_DEV)/core/DesktopEditor/allthemesgen && \
	cmake --build .

core/pluginsmanager:
	@echo "Building core/pluginsmanager..."
	mkdir -p /build/pluginsmanager
	cd /build/pluginsmanager && \
	cmake -GNinja $(BUILD_FLAGS) $(EO_DEV)/core/DesktopEditor/pluginsmanager && \
	cmake --build .

core/x2t:
	@echo "Building core/x2t..."
	mkdir -p /build/x2t
	cd /build/x2t && \
	cmake -GNinja $(BUILD_FLAGS) $(EO_DEV)/core/X2tConverter/build/cmake && \
	cmake --build .

core/docbuilder:
	@echo "Building core/docbuilder..."
	mkdir -p /build/docbuilder
	cd /build/docbuilder && \
	cmake -GNinja $(BUILD_FLAGS) $(EO_DEV)/core/DesktopEditor/doctrenderer/app_builder && \
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
	cd $(EO_DEV)/server/DocService && \
	npm install && \
	pkg . -t linux-x64 --node-options="--max_old_space_size=4096" -o ${EO_ROOT}/server/DocService/docservice && \
	supervisorctl restart docservice

server/converter: server/common
	cd $(EO_DEV)/server/FileConverter && \
	npm install && \
	pkg . -t linux-x64 --node-options="--max_old_space_size=4096" -o ${EO_ROOT}/server/FileConverter/converter && \
	supervisorctl restart converter

server/metrics: server/common
	cd $(EO_DEV)/server/Metrics && \
	npm install && \
	pkg . -t linux-x64 --node-options="--max_old_space_size=4096" -o ${EO_ROOT}/server/Metrics/metrics && \
	supervisorctl restart metrics

server/adminp: server/common server/adminp/cli server/adminp/srv

server/adminp/srv: server/common
	cd $(EO_DEV)/server/AdminPanel/server && \
	npm install && \
	pkg . -t linux-x64 --node-options="--max_old_space_size=4096" -o ${EO_ROOT}/server/AdminPanel/server/adminpanel && \
	supervisorctl restart adminpanel

server/adminp/cli: server/common
	cd $(EO_DEV)/server/AdminPanel/client && \
	npm install && \
	BUILD_ROOT=$(EO_ROOT) npm run build