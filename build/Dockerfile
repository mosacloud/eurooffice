# Bring in the upstream OnlyOffice Document Server image so that
# we can extract things from it later
FROM onlyoffice/documentserver:latest AS upstream

ARG BUILD_ROOT=/package


#### BASE ####
FROM debian:trixie AS base
    RUN apt update && \
        apt install -y nodejs npm openjdk-21-jdk wget zip brotli && \
        npm install -g @yao-pkg/pkg grunt-cli



#### CORE ####
FROM ubuntu AS core
    ARG BUILD_ROOT

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
        cmake -GNinja -DCMAKE_BUILD_TYPE=Debug -DCMAKE_CXX_FLAGS_DEBUG="-g -O0" -DCMAKE_C_FLAGS_DEBUG="-g -O0" /core
        cmake --build .
        mkdir -p ${BUILD_ROOT}
        cp -r /build-cache/package/* ${BUILD_ROOT}/
EOF

#### SDKJS ####
FROM base AS sdkjs

    ARG BUILD_ROOT

    COPY sdkjs/build/package*.json /app/build/

    RUN --mount=type=cache,target=/root/.npm \
        cd app/build && \
        npm install

    COPY sdkjs/ /app

    ENV BUILD_ROOT=${BUILD_ROOT}

    RUN cd app/build && \
        grunt

#### WEB-APPS ####
FROM base AS web-apps
    ARG PRODUCT_VERSION
    ARG BUILD_ROOT

    COPY web-apps/build/package*.json /app/build/
    COPY web-apps/build/sprites/package*.json /app/build/sprites/
    COPY web-apps/build/plugins/grunt-inline/package*.json /app/build/plugins/grunt-inline/

    RUN --mount=type=cache,target=/root/.npm \
        cd app/build && \
        npm ci


    COPY web-apps/ /app

    ENV PRODUCT_VERSION=${PRODUCT_VERSION}
    ENV BUILD_ROOT=${BUILD_ROOT}

    RUN cd app/build && \
        THEME=nextcloud grunt

#### SERVER-BASE ####
FROM base AS server
    ARG PRODUCT_VERSION
    ARG BUILD_ROOT

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

    RUN cd /server/DocService && \
        pkg . -t linux-x64 --node-options="--max_old_space_size=4096" -o ${BUILD_ROOT}/docservice

    RUN cd /server/FileConverter && \
        pkg . -t linux-x64 --node-options="--max_old_space_size=4096" -o ${BUILD_ROOT}/fileconverter

    RUN cd /server/Metrics && \
        pkg . -t linux-x64 --node-options="--max_old_space_size=4096" -o ${BUILD_ROOT}/metrics

    RUN cd /server/AdminPanel/server && \
        pkg . -t linux-x64 --node-options="--max_old_space_size=4096" -o ${BUILD_ROOT}/adminpanel

    RUN cd /server/AdminPanel/client && \
        npm run build && \
        cp -r build ${BUILD_ROOT}/



#### FINAL UPSTREAM IMAGE ####
# This image is based on the upstream OnlyOffice Document Server image
# but with our built components copied into it. 
# This is the first step to proof we are able to build components
# successfully and integrate them into the Document Server.
# Later, we will create a final image that contains only the
# built components and necessary runtime files and dependency services like
# PostgreSQL, Redis, RabbitMQ

FROM upstream AS finalupstream
    ARG PRODUCT_VERSION
    ARG BUILD_ROOT

    COPY --from=sdkjs ${BUILD_ROOT} /var/www/onlyoffice/documentserver/sdkjs
    COPY --from=web-apps ${BUILD_ROOT} /var/www/onlyoffice/documentserver/web-apps

    COPY --from=core ${BUILD_ROOT}/* /var/www/onlyoffice/documentserver/server/FileConverter/bin/

    RUN mv -f /var/www/onlyoffice/documentserver/server/FileConverter/bin/allfontsgen    /var/www/onlyoffice/documentserver/server/tools/ && \
        mv -f /var/www/onlyoffice/documentserver/server/FileConverter/bin/allthemesgen   /var/www/onlyoffice/documentserver/server/tools/ && \
        mv -f /var/www/onlyoffice/documentserver/server/FileConverter/bin/pluginsmanager /var/www/onlyoffice/documentserver/server/tools/


    COPY --from=server ${BUILD_ROOT}/docservice /var/www/onlyoffice/documentserver/server/DocService/docservice
    COPY --from=server ${BUILD_ROOT}/fileconverter /var/www/onlyoffice/documentserver/server/FileConverter/converter
    COPY --from=server ${BUILD_ROOT}/metrics /var/www/onlyoffice/documentserver/server/Metrics/metrics
    COPY --from=server ${BUILD_ROOT}/adminpanel /var/www/onlyoffice/documentserver/server/AdminPanel/server/adminpanel

    RUN sed 's,autostart=false,autostart=true,' -i /etc/supervisor/conf.d/ds-example.conf

    # COPY ./onlyoffice.github.io/sdkjs-plugins /sdkjs-plugins

#### FINAL UBUNTU ####
FROM ubuntu:24.04 AS finalubuntu
    ARG PRODUCT_VERSION
    ARG BUILD_ROOT

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
                nginx-extras
    
    ## Copy the table scheme for postgres
    COPY fork/build/build_files/config/postgres /var/www/onlyoffice/documentserver/server/schema/postgresql

    ## Configure Postgres Server
    RUN service postgresql start && \
        sudo -u postgres psql -c "CREATE USER onlyoffice WITH password 'onlyoffice';" && \
        sudo -u postgres psql -c "CREATE DATABASE onlyoffice OWNER onlyoffice;" && \
        sudo -u postgres bash -c "PGPASSWORD=onlyoffice psql -h localhost -U onlyoffice -d onlyoffice -f /var/www/onlyoffice/documentserver/server/schema/postgresql/createdb.sql"
    
    ## Create folder structure
    RUN rm -f /etc/nginx/sites-enabled/default && \
        mkdir -p /var/log/onlyoffice/documentserver/docservice \
                 /var/log/onlyoffice/documentserver/converter \
                 /var/log/onlyoffice/documentserver/adminpanel \
                 /var/log/onlyoffice/documentserver/metrics \
                 /var/www/onlyoffice/documentserver/sdkjs-plugins \
                 /var/www/onlyoffice/documentserver/fonts && \
        touch /var/log/onlyoffice/documentserver/nginx.error.log

    ## Copy sdkjs and web-apps builds
    COPY --from=sdkjs ${BUILD_ROOT} /var/www/onlyoffice/documentserver/
    COPY --from=web-apps ${BUILD_ROOT} /var/www/onlyoffice/documentserver/

    ## Copy core builds
    COPY --from=core ${BUILD_ROOT}/* /var/www/onlyoffice/documentserver/server/FileConverter/bin/
    RUN mkdir /var/www/onlyoffice/documentserver/server/tools/ && \
        mv /var/www/onlyoffice/documentserver/server/FileConverter/bin/allfontsgen    /var/www/onlyoffice/documentserver/server/tools/ && \
        mv /var/www/onlyoffice/documentserver/server/FileConverter/bin/allthemesgen   /var/www/onlyoffice/documentserver/server/tools/ && \
        mv /var/www/onlyoffice/documentserver/server/FileConverter/bin/pluginsmanager /var/www/onlyoffice/documentserver/server/tools/


    ## Copy server builds
    COPY --from=server ${BUILD_ROOT}/docservice /var/www/onlyoffice/documentserver/server/DocService/docservice
    COPY --from=server ${BUILD_ROOT}/fileconverter /var/www/onlyoffice/documentserver/server/FileConverter/converter
    COPY --from=server ${BUILD_ROOT}/metrics /var/www/onlyoffice/documentserver/server/Metrics/metrics
    COPY --from=server ${BUILD_ROOT}/adminpanel /var/www/onlyoffice/documentserver/server/AdminPanel/server/adminpanel
    COPY --from=server ${BUILD_ROOT}/build /var/www/onlyoffice/documentserver/server/AdminPanel/client/build

    ## Copy the core fonts
    COPY core-fonts /var/www/onlyoffice/documentserver/core-fonts

    ## Copy onlyoffice config files
    COPY fork/build/build_files/config/onlyoffice/default.json /etc/onlyoffice/documentserver/default.json
    COPY fork/build/build_files/config/onlyoffice/development-linux.json /etc/onlyoffice/documentserver/development-linux.json
    COPY fork/build/build_files/config/onlyoffice/log4js/development.json /etc/onlyoffice/documentserver/log4js/development.json 
    COPY fork/build/build_files/config/onlyoffice/local.json /etc/onlyoffice/documentserver/local.json

    ## Copy metrics config files
    COPY fork/build/build_files/config/metrics/config/config.js /var/www/onlyoffice/documentserver/server/Metrics/config/config.js

    ## Copy nginx config files
    COPY fork/build/build_files/config/nginx/conf.d /etc/nginx/conf.d/
    COPY fork/build/build_files/config/nginx/includes /etc/nginx/includes/


    ## Copy some binaries for testing (should be removed/self-compiled in the end)
    COPY fork/build/build_files/config/core/DoctRenderer.config /var/www/onlyoffice/documentserver/server/FileConverter/bin/DoctRenderer.config
    COPY fork/build/build_files/config/core/cmap.bin /var/www/onlyoffice/documentserver/server/FileConverter/bin/cmap.bin

    ## Copy scripts
    COPY fork/build/build_files/scripts/documentserver-flush-cache.sh /usr/bin/documentserver-flush-cache.sh
    COPY fork/build/build_files/scripts/documentserver-generate-allfonts.sh /usr/bin/documentserver-generate-allfonts.sh

    RUN /usr/bin/documentserver-flush-cache.sh -r false

    
    COPY fork/build/build_files/scripts/entrypoint.sh /entrypoint.sh
    RUN chmod +x /entrypoint.sh

    ENTRYPOINT ["/entrypoint.sh"]
