#### BASE ####
FROM ubuntu:24.04 AS base
    RUN apt-get update && \
        apt-get install -y ca-certificates curl gnupg openjdk-21-jdk wget zip brotli && \
        curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
        apt-get install -y nodejs && \
        npm install -g @yao-pkg/pkg grunt-cli && \
        rm -rf /var/lib/apt/lists/*

#### CORE ####
FROM ubuntu:24.04 AS core
ARG BUILD_ROOT=/package

ENV TZ=Etc/UTC
ENV DEBIAN_FRONTEND=noninteractive
ENV PLEASE_PRELOAD_LIBSTDCPP=true

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        git curl sudo wget ssh \
        build-essential make cmake ninja-build pkg-config \
        libglib2.0-dev \
        python3 python-is-python3 python3-venv python3-setuptools \
        python3-httplib2 \
        lsb-release libboost-all-dev findutils \
        gn \
    && rm -rf /var/lib/apt/lists/*

# clang-13 required for V8 9.x — only available on jammy (22.04), not noble (24.04)
RUN wget -qO - https://apt.llvm.org/llvm-snapshot.gpg.key | \
    gpg --dearmor -o /etc/apt/keyrings/llvm-snapshot.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/llvm-snapshot.gpg] http://apt.llvm.org/jammy/ llvm-toolchain-jammy-13 main" \
    > /etc/apt/sources.list.d/llvm-13.list && \
    apt-get update && apt-get install -y \
        clang-13 lld-13 llvm-13-dev llvm-13 \
        libc++-13-dev libc++abi-13-dev \
        qemu-user-static binfmt-support && \
    rm -rf /var/lib/apt/lists/*

# set clang 13 as standard
RUN update-alternatives --install /usr/bin/clang clang /usr/bin/clang-13 100 && \
    update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-13 100 && \
    update-alternatives --install /usr/bin/llvm-ar llvm-ar /usr/bin/llvm-ar-13 100 && \
    update-alternatives --install /usr/bin/llvm-nm llvm-nm /usr/bin/llvm-nm-13 100 && \
    update-alternatives --install /usr/bin/llvm-ranlib llvm-ranlib /usr/bin/llvm-ranlib-13 100 && \
    update-alternatives --install /usr/bin/lld lld /usr/bin/lld-13 100


ENV PATH="/root/.cargo/bin:${PATH}"

# Git needs to allow repo paths copied by Docker
RUN git config --global --add safe.directory '*'

# upstream behavior — unchanged
COPY core /core

ENV BUILD_ROOT=${BUILD_ROOT}

RUN --mount=type=cache,target=/build-cache \
    --mount=type=cache,target=/package/third_party/install \
<<EOF
set -e
mkdir -p ${BUILD_ROOT}
cd /build-cache

cmake -GNinja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_CXX_FLAGS_RELEASE="-O3 -w" \
  -DCMAKE_C_FLAGS_RELEASE="-O3 -w" \
  -DEO_CORE_OUTPUT_DIR=${BUILD_ROOT}/bin \
  -DEO_CORE_TOOLS_DIR=${BUILD_ROOT}/tools \
  /core

cmake --build .
EOF


#### CORE WASM ####
FROM emscripten/emsdk:latest AS core-wasm 
    ARG BUILD_ROOT=/package

    ENV BUILD_ROOT=${BUILD_ROOT}

    COPY core /core

    # hash wasm has one dependency in sdkjs which we must copy here (TODO: fix this)
    COPY sdkjs/common/stringserialize.js /sdkjs/common/stringserialize.js

    RUN --mount=type=cache,target=/build-cache1 <<EOF
        cd /build-cache1
        /bin/bash -c "emcmake cmake -DEO_CORE_OUTPUT_DIR=${BUILD_ROOT} /core && cmake --build ."
EOF


#### SDKJS ####
FROM base AS sdkjs
ARG TARGETARCH
ARG BUILD_ROOT=/package

COPY sdkjs/build/package*.json /app/build/

RUN --mount=type=cache,target=/root/.npm \
    cd /app/build && npm install

COPY sdkjs/ /app

ENV BUILD_ROOT=${BUILD_ROOT}

RUN cd /app/build && grunt

    ## Copy core wasm builds
    COPY --from=core-wasm ${BUILD_ROOT}/engine/ /app/pdf/src/engine/
    COPY --from=core-wasm ${BUILD_ROOT}/zlib/ /app/common/zlib/
    COPY --from=core-wasm ${BUILD_ROOT}/hash/ /app/common/hash/
    COPY --from=core-wasm ${BUILD_ROOT}/spell/ /app/common/spell/
    COPY --from=core-wasm ${BUILD_ROOT}/libfont/ /app/common/libfont/

    RUN cd /app/build && \
        CC_PLATFORM=$(if [ "$TARGETARCH" = "arm64" ]; then echo "java"; else echo "native,java"; fi) grunt

#### WEB-APPS ####
FROM base AS web-apps
ARG TARGETARCH
ARG PRODUCT_VERSION
ARG BUILD_ROOT=/package

COPY web-apps/build/package*.json /app/build/
COPY web-apps/build/sprites/package*.json /app/build/sprites/
COPY web-apps/build/plugins/grunt-inline/ /app/build/plugins/grunt-inline/

RUN --mount=type=cache,target=/root/.npm \
     cd /app/build && npm install

RUN npm install --save-dev imagemin-gifsicle imagemin-jpegtran imagemin-optipng imagemin-svgo || true

COPY web-apps/ /app

ENV PRODUCT_VERSION=${PRODUCT_VERSION}
ENV BUILD_ROOT=${BUILD_ROOT}

RUN cd app/build && \
        THEME=euro-office grunt $(if [ "$TARGETARCH" = "arm64" ]; then echo "--skip-imagemin"; fi)

#### SERVER ####
FROM base AS server
ARG TARGETARCH
ARG PRODUCT_VERSION
ARG BUILD_ROOT=/package

ENV PRODUCT_VERSION=${PRODUCT_VERSION}

COPY server/Common/package*.json /server/Common/
RUN --mount=type=cache,target=/root/.npm cd /server/Common && npm install

COPY server/DocService/package*.json /server/DocService/
RUN --mount=type=cache,target=/root/.npm cd /server/DocService && npm install

COPY server/FileConverter/package*.json /server/FileConverter/
RUN --mount=type=cache,target=/root/.npm cd /server/FileConverter && npm install

COPY server/Metrics/package*.json /server/Metrics/
RUN --mount=type=cache,target=/root/.npm cd /server/Metrics && npm install

COPY server/AdminPanel/server/package*.json /server/AdminPanel/server/
RUN --mount=type=cache,target=/root/.npm cd /server/AdminPanel/server && npm install

COPY server/AdminPanel/client/package*.json /server/AdminPanel/client/
RUN --mount=type=cache,target=/root/.npm cd /server/AdminPanel/client && npm install

COPY server/ /server

ENV BUILD_ROOT=${BUILD_ROOT}

RUN TARGETARCH_PKG=$(echo "$TARGETARCH" | sed 's/amd64/x64/') && \
    cd /server/Common && \
    sed "s|\(const buildVersion = \).*|\1'${PRODUCT_VERSION}';|" -i sources/commondefines.js && \
    cd /server/DocService && \
    pkg . -t linux-"$TARGETARCH_PKG" --node-options="--max_old_space_size=4096" -o "${BUILD_ROOT}/docservice" && \
    cd /server/FileConverter && \
    pkg . -t linux-"$TARGETARCH_PKG" --node-options="--max_old_space_size=4096" -o "${BUILD_ROOT}/fileconverter" && \
    cd /server/Metrics && \
    pkg . -t linux-"$TARGETARCH_PKG" --node-options="--max_old_space_size=4096" -o "${BUILD_ROOT}/metrics" && \
    cd /server/AdminPanel/server && \
    pkg . -t linux-"$TARGETARCH_PKG" --node-options="--max_old_space_size=4096" -o "${BUILD_ROOT}/adminpanel"

RUN cd /server/AdminPanel/client && npm run build

#### DOCUMENTSERVER-EXAMPLE ####
FROM base AS build-example
ARG TARGETARCH
COPY document-server-integration/web/documentserver-example/nodejs/package*.json /app/build/
RUN --mount=type=cache,target=/root/.npm cd /app/build && npm install
COPY document-server-integration/web/documentserver-example/nodejs /app
WORKDIR /app
RUN TARGETARCH_PKG=$(echo "$TARGETARCH" | sed 's/amd64/x64/') && \
pkg . -t linux-"$TARGETARCH_PKG" --node-options="--max_old_space_size=4096" -o /app/example

FROM scratch AS example
    COPY --from=build-example /app/ /example

#### FINAL UBUNTU ####
FROM ubuntu:24.04 AS finalubuntu
ARG PRODUCT_VERSION
ARG BUILD_ROOT=/package

ARG EO_ROOT=/var/www/onlyoffice/documentserver
ARG EO_LOG=/var/log/onlyoffice/documentserver
ARG EO_CONF=/etc/onlyoffice/documentserver

ENV EO_ROOT=${EO_ROOT}
ENV EO_LOG=${EO_LOG}
ENV EO_CONF=${EO_CONF}

RUN apt-get -y update && \
    ACCEPT_EULA=Y apt-get -yq install \
        postgresql postgresql-client redis-server rabbitmq-server \
        nginx sudo gdb nginx-extras supervisor jq util-linux && \
    rm -rf /var/lib/apt/lists/*

# Create the 'ds' user that is required by OnlyOffice scripts
RUN useradd -r -s /bin/false ds || true

COPY build/configs/postgres ${EO_ROOT}/server/schema/postgresql

RUN service postgresql start && \
    sudo -u postgres psql -c "CREATE USER onlyoffice WITH password 'onlyoffice';" && \
    sudo -u postgres psql -c "CREATE DATABASE onlyoffice OWNER onlyoffice;" && \
    sudo -u postgres bash -c "PGPASSWORD=onlyoffice psql -h localhost -U onlyoffice -d onlyoffice -f ${EO_ROOT}/server/schema/postgresql/createdb.sql"

## Copy dictionary
COPY dictionaries /var/www/onlyoffice/documentserver/dictionaries
COPY document-templates /var/www/onlyoffice/documentserver/document-templates

RUN rm -f /etc/nginx/sites-enabled/default && \
    mkdir -p ${EO_LOG}/docservice ${EO_LOG}/converter \
             ${EO_LOG}/adminpanel ${EO_LOG}/metrics \
             ${EO_ROOT}/sdkjs-plugins ${EO_ROOT}/fonts && \
    touch ${EO_LOG}/nginx.error.log

COPY --from=sdkjs ${BUILD_ROOT} ${EO_ROOT}/
COPY --from=web-apps ${BUILD_ROOT} ${EO_ROOT}/

# Copy all core binaries and tools (including libgraphics.so for shared libraries)
COPY --from=core ${BUILD_ROOT}/bin/ ${EO_ROOT}/server/FileConverter/bin/
COPY --from=core ${BUILD_ROOT}/tools/ ${EO_ROOT}/server/tools/

# Copy ICU libraries from the package root in core stage
RUN mkdir -p ${EO_ROOT}/server/FileConverter/lib ${EO_ROOT}/server/tools
COPY --from=core ${BUILD_ROOT}/*.so* ${EO_ROOT}/server/FileConverter/lib/
COPY --from=core ${BUILD_ROOT}/tools/*.so* ${EO_ROOT}/server/tools/

COPY --from=server ${BUILD_ROOT}/docservice    ${EO_ROOT}/server/DocService/docservice
COPY --from=server ${BUILD_ROOT}/fileconverter ${EO_ROOT}/server/FileConverter/converter
COPY --from=server ${BUILD_ROOT}/metrics       ${EO_ROOT}/server/Metrics/metrics
COPY --from=server ${BUILD_ROOT}/adminpanel    ${EO_ROOT}/server/AdminPanel/server/adminpanel
COPY --from=server ${BUILD_ROOT}/build         ${EO_ROOT}/server/AdminPanel/client/build

COPY core-fonts ${EO_ROOT}/core-fonts

# Install example app
COPY --from=example /example/example /var/www/onlyoffice/documentserver-example/example
RUN mkdir -p /var/www/onlyoffice/documentserver-example/files
# Copy patched config file default.json
COPY --from=example /example/config/* /etc/onlyoffice/documentserver-example/


# Create required config directories and files
RUN mkdir -p ${EO_ROOT}/server/Common/config && \
    touch ${EO_ROOT}/server/Common/config/runtime.json && \
    echo '{}' > ${EO_ROOT}/server/Common/config/runtime.json

# Set proper permissions for OnlyOffice directories (fixes EACCES permission denied)
RUN mkdir -p /var/lib/onlyoffice && \
    chown -R ds:ds /var/www/onlyoffice /var/lib/onlyoffice /var/log/onlyoffice

# Copy log4js configuration first before trying to use it
COPY build/configs/onlyoffice/default.json            ${EO_CONF}/default.json
COPY build/configs/onlyoffice/development-linux.json  ${EO_CONF}/development-linux.json
COPY build/configs/onlyoffice/local.json              ${EO_CONF}/local.json
COPY build/configs/onlyoffice/log4js/development.json ${EO_CONF}/log4js/development.json

RUN mkdir -p /var/www/onlyoffice/documentserver && \
    cp ${EO_CONF}/log4js/development.json /var/www/onlyoffice/documentserver/log4js.json

COPY build/configs/metrics/config/config.js ${EO_ROOT}/server/Metrics/config/config.js
COPY build/configs/nginx/conf.d /etc/nginx/conf.d/
COPY build/configs/nginx/includes /etc/nginx/includes/

COPY build/configs/core/DoctRenderer.config ${EO_ROOT}/server/FileConverter/bin/DoctRenderer.config

COPY --chmod=755 build/scripts/documentserver-flush-cache.sh /usr/bin/documentserver-flush-cache.sh
COPY --chmod=755 build/scripts/documentserver-generate-allfonts.sh /usr/bin/documentserver-generate-allfonts.sh
COPY build/configs/supervisor/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

RUN /usr/bin/documentserver-flush-cache.sh -r false

COPY build/scripts/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]


FROM finalubuntu AS develop
ARG PRODUCT_VERSION
ENV TZ=Etc/UTC

RUN apt-get update && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs npm openjdk-21-jdk wget zip brotli && \
    npm install -g @yao-pkg/pkg grunt-cli && \
    rm -rf /var/lib/apt/lists/*

    RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
        apt-get -y update && \
        apt-get -y upgrade && \
        apt-get -y install \
                    git \
                    curl \
                    sudo \
                    wget \
                    ssh \
                    build-essential \
                    make \
                    cmake \
                    ninja-build \
                    pkg-config \
                    libglib2.0-dev \
                    python3 \
                    python-is-python3 \
                    lsb-release \
                    libboost-all-dev \
                    tar \
                    xz-utils \
                    libtool-bin \
                    autoconf \
                    python3-dev \
                    && \
        rm -rf /var/lib/apt/lists/*

    ## Install Emscripten
    RUN wget -qO emsdk.tar.gz https://github.com/emscripten-core/emsdk/archive/main.tar.gz && \
        mkdir /opt/emsdk && \
        tar xf emsdk.tar.gz --strip-components=1 -C /opt/emsdk && \
        /opt/emsdk/emsdk install latest && \
        /opt/emsdk/emsdk activate latest && \
        chmod +x /opt/emsdk/emsdk_env.sh && \
        rm -rf emsdk.tar.gz

    # hardcoded for now. todo: get from whatever is defined in upstream
    ENV PRODUCT_VERSION=${PRODUCT_VERSION}
    ENV EO_DEV=/develop
    ENV THEME=euro-office
