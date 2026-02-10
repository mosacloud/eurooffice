# Bring in the upstream OnlyOffice Document Server image so that
# we can extract things from it later
FROM onlyoffice/documentserver:latest AS upstream

ARG BUILD_ROOT=/package

#### BASE ####
FROM ubuntu:24.04 AS base
    RUN apt update && \
        apt install -y ca-certificates curl gnupg openjdk-21-jdk wget zip brotli && \
        curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
        apt install -y nodejs && \
        npm install -g @yao-pkg/pkg grunt-cli



#### CORE (built from source on amd64) ####
FROM ubuntu AS core-amd64
    ARG BUILD_ROOT=/package

    ENV TZ=Etc/UTC
    ENV DEBIAN_FRONTEND=noninteractive
    ENV PLEASE_PRELOAD_LIBSTDCPP=true

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
                    findutils \
                    && \
        rm -rf /var/lib/apt-get/lists/*

    COPY core /core

    ENV BUILD_ROOT=${BUILD_ROOT}

    RUN --mount=type=cache,target=/build-cache <<EOF
        cd /build-cache
        cmake -GNinja -DCMAKE_BUILD_TYPE=Debug -DCMAKE_CXX_FLAGS_DEBUG="-g -O0" -DCMAKE_C_FLAGS_DEBUG="-g -O0" -DEO_CORE_OUTPUT_DIR=${BUILD_ROOT}/bin -DEO_CORE_TOOLS_DIR=${BUILD_ROOT}/tools /core
        cmake --build .
EOF

#### CORE (use upstream binaries on arm64 — V8's bundled clang can't run under QEMU) ####
FROM upstream AS core-arm64
    ARG BUILD_ROOT=/package
    RUN mkdir -p ${BUILD_ROOT}/bin && \
        mkdir -p ${BUILD_ROOT}/tools && \
        cp -a /var/www/onlyoffice/documentserver/server/FileConverter/bin/* ${BUILD_ROOT}/bin && \
        cp -a /var/www/onlyoffice/documentserver/server/tools/* ${BUILD_ROOT}/tools

FROM core-${TARGETARCH} AS core


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

    ARG BUILD_ROOT=/package

    COPY sdkjs/build/package*.json /app/build/

    RUN --mount=type=cache,target=/root/.npm \
        cd app/build && \
        npm install

    COPY sdkjs/ /app

    ENV BUILD_ROOT=${BUILD_ROOT}

    ## Copy core wasm builds
    COPY --from=core-wasm ${BUILD_ROOT}/engine/ /app/pdf/src/engine/
    COPY --from=core-wasm ${BUILD_ROOT}/zlib/ /app/common/zlib/
    COPY --from=core-wasm ${BUILD_ROOT}/hash/ /app/common/hash/
    COPY --from=core-wasm ${BUILD_ROOT}/spell/ /app/common/spell/
    COPY --from=core-wasm ${BUILD_ROOT}/libfont/ /app/common/libfont/

    ARG TARGETARCH
    RUN cd app/build && \
        CC_PLATFORM=$(if [ "$TARGETARCH" = "arm64" ]; then echo "java"; else echo "native,java"; fi) grunt

#### WEB-APPS ####
FROM base AS web-apps
    ARG PRODUCT_VERSION
    ARG BUILD_ROOT=/package

    COPY web-apps/build/package*.json /app/build/
    COPY web-apps/build/sprites/package*.json /app/build/sprites/
    COPY web-apps/build/plugins/grunt-inline/ /app/build/plugins/grunt-inline/

    RUN --mount=type=cache,target=/root/.npm \
        cd app/build && \
        npm install


    COPY web-apps/ /app

    ENV PRODUCT_VERSION=${PRODUCT_VERSION}
    ENV BUILD_ROOT=${BUILD_ROOT}

    ARG TARGETARCH
    RUN cd app/build && \
        THEME=nextcloud grunt $(if [ "$TARGETARCH" = "arm64" ]; then echo "--skip-imagemin"; fi)

#### SERVER ####
FROM base AS server
    ARG PRODUCT_VERSION
    ARG BUILD_ROOT=/package
    ARG TARGETARCH

    ENV PRODUCT_VERSION=${PRODUCT_VERSION}

    COPY server/Common/package*.json /server/Common/
    RUN --mount=type=cache,target=/root/.npm \
        cd /server/Common && \
        npm install

    COPY server/DocService/package*.json /server/DocService/
    RUN --mount=type=cache,target=/root/.npm \
        cd /server/DocService && \
        npm install

    COPY server/FileConverter/package*.json /server/FileConverter/
    RUN --mount=type=cache,target=/root/.npm \
        cd /server/FileConverter && \
        npm install

    COPY server/Metrics/package*.json /server/Metrics/
    RUN --mount=type=cache,target=/root/.npm \
        cd /server/Metrics && \
        npm install

    COPY server/AdminPanel/server/package*.json /server/AdminPanel/server/
    RUN --mount=type=cache,target=/root/.npm \
        cd /server/AdminPanel/server && \
        npm install

    COPY server/AdminPanel/client/package*.json /server/AdminPanel/client/
    RUN --mount=type=cache,target=/root/.npm \
        cd /server/AdminPanel/client && \
        npm install

    COPY server/ /server

    ENV BUILD_ROOT=${BUILD_ROOT}

    RUN cd /server/Common && \
        sed "s|\(const buildVersion = \).*|\1'${PRODUCT_VERSION}';|" -i sources/commondefines.js

    RUN PKG_TARGET=$(if [ "$TARGETARCH" = "arm64" ]; then echo "linux-arm64"; else echo "linux-x64"; fi) && \
        cd /server/DocService && \
        pkg . -t $PKG_TARGET --node-options="--max_old_space_size=4096" -o ${BUILD_ROOT}/docservice

    RUN PKG_TARGET=$(if [ "$TARGETARCH" = "arm64" ]; then echo "linux-arm64"; else echo "linux-x64"; fi) && \
        cd /server/FileConverter && \
        pkg . -t $PKG_TARGET --node-options="--max_old_space_size=4096" -o ${BUILD_ROOT}/fileconverter

    RUN PKG_TARGET=$(if [ "$TARGETARCH" = "arm64" ]; then echo "linux-arm64"; else echo "linux-x64"; fi) && \
        cd /server/Metrics && \
        pkg . -t $PKG_TARGET --node-options="--max_old_space_size=4096" -o ${BUILD_ROOT}/metrics

    RUN PKG_TARGET=$(if [ "$TARGETARCH" = "arm64" ]; then echo "linux-arm64"; else echo "linux-x64"; fi) && \
        cd /server/AdminPanel/server && \
        pkg . -t $PKG_TARGET --node-options="--max_old_space_size=4096" -o ${BUILD_ROOT}/adminpanel

    RUN cd /server/AdminPanel/client && \
        npm run build

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

    ## Install necessary requirements
    RUN apt-get -y update && \
        ACCEPT_EULA=Y apt-get -yq install \
                postgresql \
                postgresql-client \
                redis-server \
                rabbitmq-server \
                nginx \
                sudo \
                gdb \
                nginx-extras \
                supervisor \
                jq
    
    ## Copy the table scheme for postgres
    COPY build/configs/postgres ${EO_ROOT}/server/schema/postgresql

    ## Configure Postgres Server
    RUN service postgresql start && \
        sudo -u postgres psql -c "CREATE USER onlyoffice WITH password 'onlyoffice';" && \
        sudo -u postgres psql -c "CREATE DATABASE onlyoffice OWNER onlyoffice;" && \
        sudo -u postgres bash -c "PGPASSWORD=onlyoffice psql -h localhost -U onlyoffice -d onlyoffice -f ${EO_ROOT}/server/schema/postgresql/createdb.sql"
    
    ## Create folder structure
    RUN rm -f /etc/nginx/sites-enabled/default && \
        mkdir -p ${EO_LOG}/docservice \
                 ${EO_LOG}/converter \
                 ${EO_LOG}/adminpanel \
                 ${EO_LOG}/metrics \
                 ${EO_ROOT}/sdkjs-plugins \
                 ${EO_ROOT}/fonts && \
        touch ${EO_LOG}/nginx.error.log

    ## Copy sdkjs and web-apps builds
    COPY --from=sdkjs ${BUILD_ROOT} ${EO_ROOT}/
    COPY --from=web-apps ${BUILD_ROOT} ${EO_ROOT}/

    ## Copy core builds
    COPY --from=core ${BUILD_ROOT}/bin/* ${EO_ROOT}/server/FileConverter/bin/
    COPY --from=core ${BUILD_ROOT}/tools/* ${EO_ROOT}/server/tools/        

    ## Copy dictionary
    COPY dictionaries /var/www/onlyoffice/documentserver/dictionaries
    COPY document-templates /var/www/onlyoffice/documentserver/document-templates

    ## Copy server builds
    COPY --from=server ${BUILD_ROOT}/docservice    ${EO_ROOT}/server/DocService/docservice
    COPY --from=server ${BUILD_ROOT}/fileconverter ${EO_ROOT}/server/FileConverter/converter
    COPY --from=server ${BUILD_ROOT}/metrics       ${EO_ROOT}/server/Metrics/metrics
    COPY --from=server ${BUILD_ROOT}/adminpanel    ${EO_ROOT}/server/AdminPanel/server/adminpanel
    COPY --from=server ${BUILD_ROOT}/build         ${EO_ROOT}/server/AdminPanel/client/build

    ## Copy the core fonts
    COPY core-fonts ${EO_ROOT}/core-fonts

    ## Copy onlyoffice config files
    COPY build/configs/onlyoffice/default.json            ${EO_CONF}/default.json
    COPY build/configs/onlyoffice/development-linux.json  ${EO_CONF}/development-linux.json
    COPY build/configs/onlyoffice/log4js/development.json ${EO_CONF}/log4js/development.json 
    COPY build/configs/onlyoffice/local.json              ${EO_CONF}/local.json

    ## Copy metrics config files
    COPY build/configs/metrics/config/config.js ${EO_ROOT}/server/Metrics/config/config.js

    ## Copy nginx config files
    COPY build/configs/nginx/conf.d /etc/nginx/conf.d/
    COPY build/configs/nginx/includes /etc/nginx/includes/


    ## Copy some binaries for testing (should be removed/self-compiled in the end)
    COPY build/configs/core/DoctRenderer.config ${EO_ROOT}/server/FileConverter/bin/DoctRenderer.config

    ## Copy scripts
    COPY build/scripts/documentserver-flush-cache.sh /usr/bin/documentserver-flush-cache.sh
    COPY build/scripts/documentserver-generate-allfonts.sh /usr/bin/documentserver-generate-allfonts.sh

    ## Copy supervisor config
    COPY build/configs/supervisor/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

    RUN /usr/bin/documentserver-flush-cache.sh -r false

    
    COPY build/scripts/entrypoint.sh /entrypoint.sh
    RUN chmod +x /entrypoint.sh

    ENTRYPOINT ["/entrypoint.sh"]


FROM finalubuntu AS develop
    # the idea is to set up build dependencies in the from scratch 
    # container, so that we can then mount specific components, 
    # and run the build steps manually in the container
    ARG PRODUCT_VERSION

    # from base step
    RUN apt update && \
        apt install -y nodejs npm openjdk-21-jdk wget zip brotli && \
        npm install -g @yao-pkg/pkg grunt-cli
    
    # from core step
    ENV TZ=Etc/UTC
    ENV DEBIAN_FRONTEND=noninteractive
    ENV PLEASE_PRELOAD_LIBSTDCPP=true

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
        rm -rf /var/lib/apt-get/lists/*

    ## Install Emscripten
    RUN wget -qO emsdk.tar.gz https://github.com/emscripten-core/emsdk/archive/main.tar.gz && \
        mkdir /opt/emsdk && \
        tar xf emsdk.tar.gz --strip-components=1 -C /opt/emsdk && \
        /opt/emsdk/emsdk install latest && \
        /opt/emsdk/emsdk activate latest && \
        chmod +x /opt/emsdk/emsdk_env.sh && \
        /bin/bash -c "source /opt/emsdk/emsdk_env.sh" && \
        rm -rf emsdk.tar.gz

    # hardcoded for now. todo: get from whatever is defined in upstream
    ENV PRODUCT_VERSION=${PRODUCT_VERSION}
    ENV EO_DEV=/develop
    ENV THEME=nextcloud
