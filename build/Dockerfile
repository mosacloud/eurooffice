# Bring in the upstream OnlyOffice Document Server image so that
# we can extract things from it later
ARG $BASE_VERSION=24.04
ARG PACKAGE_SUFFIX=t64

FROM onlyoffice/documentserver:latest AS upstream



#### BASE ####
FROM debian:trixie AS base
    RUN apt update && \
        apt install -y nodejs npm openjdk-21-jdk wget zip brotli && \
        npm install -g @yao-pkg/pkg grunt-cli



#### CORE ####
FROM ubuntu AS core
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
                    && \
        rm -rf /var/lib/apt-get/lists/*

    RUN --mount=type=bind,source=./core,target=/core,rw <<EOF
        mkdir -p /tmp/core_build
        cd /tmp/core_build
        cmake -GNinja -DCMAKE_BUILD_TYPE=Debug -DCMAKE_CXX_FLAGS_DEBUG="-g -O0" -DCMAKE_C_FLAGS_DEBUG="-g -O0" -DEO_CORE_OUTPUT_DIR=/core_binaries /core
        cmake --build .
EOF



#### FONTS ####
# We may not need this build step in the end as it can be
# generated on the fly on the document server using
# /usr/bin/documentserver-generate-allfonts.sh
FROM base AS build-fonts
    WORKDIR /build

    COPY --from=upstream /var/www/onlyoffice/documentserver/server/FileConverter/bin/* /build/

    COPY --from=core /core_binaries /core
    RUN <<EOF
        ln -s /core/allfontsgen /build/allfontsgen
EOF

    RUN mkdir -p /build/deploy /build/core-fonts

    RUN --mount=type=bind,source=core-fonts,target=/build/core-fonts \
        ./allfontsgen --input="/build/core-fonts" \
		    --allfonts-web="/build/deploy/AllFonts-web.js" \
		    --allfonts="/build/deploy/AllFonts.js" \
		    --images="/build/deploy" \
		    --output-web="/build/deploy" \
		    --selection="/build/deploy/font_selection.bin"

FROM scratch AS fonts
    COPY --from=build-fonts /build/deploy/AllFonts.js /AllFonts.js
    COPY --from=build-fonts /build/deploy/AllFonts-web.js /AllFonts-web.js
    COPY --from=build-fonts /build/core-fonts /core-fonts



#### SDKJS ####
FROM base AS build-sdkjs
    RUN --mount=type=bind,source=./sdkjs,target=/temp,rw \
        cd /temp/build && \
        npm install && \
        grunt && \
        cp -r /temp/deploy/sdkjs /sdkjs

FROM scratch AS sdkjs
    COPY --from=build-sdkjs /sdkjs /sdkjs



#### WEB-APPS ####
FROM base AS build-web-apps
    ARG PRODUCT_VERSION

    RUN --mount=type=bind,source=./web-apps,target=/temp,rw \
        export PRODUCT_VERSION=$PRODUCT_VERSION && \
        cd /temp/build && \
        npm install && \
        grunt && \
        cp -r /temp/deploy/web-apps /web-apps

FROM scratch AS web-apps
    ARG PRODUCT_VERSION
    
    COPY --from=build-web-apps /web-apps /web-apps



#### SERVER ####
FROM base AS build-server
    ARG PRODUCT_VERSION
    
    RUN --mount=type=bind,source=./server,target=/temp,rw \
        mkdir /server && \
        cd /temp/Common && \
        export PRODUCT_VERSION=$PRODUCT_VERSION && \
        sed "s|\(const buildVersion = \).*|\1'${PRODUCT_VERSION}';|" -i sources/commondefines.js && \
        npm install && \
        #### DOCSERVICE ####
        cd /temp/DocService && \
        npm install && \
        pkg . -t linux-x64 --node-options="--max_old_space_size=4096" -o /server/docservice && \
        #### FILECONVERTER ####
        cd /temp/FileConverter && \
        npm install && \
        pkg . -t linux-x64 --node-options="--max_old_space_size=4096" -o /server/fileconverter && \
        #### METRICS ####
        cd /temp/Metrics && \
        npm install && \
        pkg . -t linux-x64 --node-options="--max_old_space_size=4096" -o /server/metrics && \
        #### ADMINPANEL ####
        cd /temp/AdminPanel/server && \
        npm install && \
        pkg . -t linux-x64 --node-options="--max_old_space_size=4096" -o /server/adminpanel && \
        #### CONFIG ####
        cp -rP /temp/Common/config /server/config


FROM scratch AS server
    COPY --from=build-server /server /server



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

    COPY --from=fonts /AllFonts-web.js /var/www/onlyoffice/documentserver/sdkjs/common/AllFonts.js
    COPY --from=fonts /AllFonts.js /var/www/onlyoffice/documentserver/server/FileConverter/bin/AllFonts.js
    COPY --from=fonts /core-fonts /var/www/onlyoffice/documentserver/core-fonts

    COPY --from=sdkjs /sdkjs /var/www/onlyoffice/documentserver/sdkjs
    COPY --from=web-apps /web-apps /var/www/onlyoffice/documentserver/web-apps

    COPY --from=core /core_binaries/* /var/www/onlyoffice/documentserver/server/FileConverter/bin/

    RUN apt-get -y update && \
        ACCEPT_EULA=Y apt-get -yq install \
        gdb && \ 
        mv -f /var/www/onlyoffice/documentserver/server/FileConverter/bin/allfontsgen    /var/www/onlyoffice/documentserver/server/tools/ && \
        mv -f /var/www/onlyoffice/documentserver/server/FileConverter/bin/allthemesgen   /var/www/onlyoffice/documentserver/server/tools/ && \
        mv -f /var/www/onlyoffice/documentserver/server/FileConverter/bin/pluginsmanager /var/www/onlyoffice/documentserver/server/tools/


    COPY --from=server /server/docservice /var/www/onlyoffice/documentserver/server/DocService/docservice
    COPY --from=server /server/fileconverter /var/www/onlyoffice/documentserver/server/FileConverter/converter
    COPY --from=server /server/metrics /var/www/onlyoffice/documentserver/server/Metrics/metrics
    COPY --from=server /server/adminpanel /var/www/onlyoffice/documentserver/server/AdminPanel/server/adminpanel

    RUN sed 's,autostart=false,autostart=true,' -i /etc/supervisor/conf.d/ds-example.conf

    # COPY ./onlyoffice.github.io/sdkjs-plugins /sdkjs-plugins


FROM ubuntu:24.04 AS finalubuntu
    ARG PRODUCT_VERSION

    ## Copy sdkjs and web-apps builds
    COPY --from=sdkjs /sdkjs /var/www/onlyoffice/documentserver/sdkjs
    COPY --from=web-apps /web-apps /var/www/onlyoffice/documentserver/web-apps

    ## Copy core builds
    COPY --from=core /core_binaries/* /var/www/onlyoffice/documentserver/server/FileConverter/bin/
    RUN mkdir /var/www/onlyoffice/documentserver/server/tools/ && \
        mv /var/www/onlyoffice/documentserver/server/FileConverter/bin/allfontsgen    /var/www/onlyoffice/documentserver/server/tools/ && \
        mv /var/www/onlyoffice/documentserver/server/FileConverter/bin/allthemesgen   /var/www/onlyoffice/documentserver/server/tools/ && \
        mv /var/www/onlyoffice/documentserver/server/FileConverter/bin/pluginsmanager /var/www/onlyoffice/documentserver/server/tools/


    ## Copy server builds
    COPY --from=server /server/docservice /var/www/onlyoffice/documentserver/server/DocService/docservice
    COPY --from=server /server/fileconverter /var/www/onlyoffice/documentserver/server/FileConverter/converter
    COPY --from=server /server/metrics /var/www/onlyoffice/documentserver/server/Metrics/metrics
    COPY --from=server /server/adminpanel /var/www/onlyoffice/documentserver/server/AdminPanel/server/adminpanel

    ## Copy the core fonts
    COPY core-fonts /var/www/onlyoffice/documentserver/core-fonts

    ## Copy the table scheme for postgres
    COPY fork/build/build_files/config/postgres /var/www/onlyoffice/documentserver/server/schema/postgresql

    ## Copy onlyoffice config files
    COPY fork/build/build_files/config/onlyoffice/default.json /etc/onlyoffice/documentserver/default.json
    COPY fork/build/build_files/config/onlyoffice/development-linux.json /etc/onlyoffice/documentserver/development-linux.json
    COPY fork/build/build_files/config/onlyoffice/log4js/development.json /etc/onlyoffice/documentserver/log4js/development.json 
    COPY fork/build/build_files/config/onlyoffice/local.json /etc/onlyoffice/documentserver/local.json


    ## Copy nginx config files
    COPY fork/build/build_files/config/nginx/conf.d /etc/nginx/conf.d/
    COPY fork/build/build_files/config/nginx/includes /etc/nginx/includes/

    ## Copy scripts
    COPY fork/build/build_files/scripts/documentserver-flush-cache.sh /usr/bin/documentserver-flush-cache.sh
    COPY fork/build/build_files/scripts/documentserver-generate-allfonts.sh /usr/bin/documentserver-generate-allfonts.sh


    ## Init the image
    RUN apt-get -y update && \
        ACCEPT_EULA=Y apt-get -yq install \
                postgresql \
                postgresql-client \
                redis-server \
                rabbitmq-server \
                nginx \
                sudo \
                gdb \
                nginx-extras && \
        service postgresql start && \
        sudo -u postgres psql -c "CREATE USER onlyoffice WITH password 'onlyoffice';" && \
        sudo -u postgres psql -c "CREATE DATABASE onlyoffice OWNER onlyoffice;" && \
        sudo -u postgres bash -c "PGPASSWORD=onlyoffice psql -h localhost -U onlyoffice -d onlyoffice -f /var/www/onlyoffice/documentserver/server/schema/postgresql/createdb.sql" && \
        rm -f /etc/nginx/sites-enabled/default && \
        mkdir -p /var/log/onlyoffice/documentserver/docservice /var/log/onlyoffice/documentserver/converter && \
        mkdir -p /var/www/onlyoffice/documentserver/sdkjs-plugins && \
        mkdir -p /var/www/onlyoffice/documentserver/fonts && \
        touch /var/log/onlyoffice/documentserver/nginx.error.log && \
        /usr/bin/documentserver-flush-cache.sh -r false

    
    COPY fork/build/build_files/scripts/entrypoint.sh /entrypoint.sh
    RUN chmod +x /entrypoint.sh

    ENTRYPOINT ["/entrypoint.sh"]

#### attempt one: WEB-APPS DEV HELPER, changes not reflecting in web-apps

FROM base AS build-web-apps-helper
    ARG PRODUCT_VERSION

    RUN --mount=type=bind,source=./web-apps,target=/temp,rw \
        export PRODUCT_VERSION=$PRODUCT_VERSION && \
        cd /temp/build && \
        npm install && \
        grunt --skip-imagemin && \
        cp -r /temp/deploy/web-apps /web-apps

FROM scratch AS web-apps-helper
    ARG PRODUCT_VERSION
    
    COPY --from=build-web-apps-helper /web-apps /web-apps

FROM finalupstream AS refresh-web-apps
    COPY --from=web-apps-helper /web-apps /var/www/onlyoffice/documentserver/web-apps


#### attempt two
FROM upstream AS develop
    # the idea is to set up build dependencies in the OO container, so that we can then mount specific components, and run the build steps manually in the container

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
                    && \
        rm -rf /var/lib/apt-get/lists/*

    # hardcoded for now. todo: get from whatever is defined in upstream
    ENV PRODUCT_VERSION=9.2.1


#### FINAL ####
# Debian 13 for the final image
FROM debian:trixie AS final

    RUN <<EOF
        apt update
        apt install -y nodejs npm

        npm install -g cross-env@5.1.2

        # Make an empty sdkjs plugins directory for now
        mkdir /sdkjs-plugins
EOF

    # https://github.com/ONLYOFFICE/build_tools/blob/cc24ee8e85be9890a77ae014bfc37aecf5209f33/scripts/deploy_server.py#L130-L142
    COPY ./onlyoffice.github.io/sdkjs-plugins /sdkjs-plugins

    # Copy each built component into the final image
    COPY --from=core /core_binaries /core
    COPY --from=sdkjs /sdkjs /sdkjs
    COPY --from=web-apps /web-apps /web-apps
    COPY --from=server /server /server

    # Set up core binaries
    RUN <<EOF
        mkdir -p /server/tools
        ln -s /core/allfontsgen /server/tools/allfontsgen
        ln -s /core/allthemes /server/tools/allthemes
        ln -s /core/docbuilder /server/tools/docbuilder
        ln -s /core/pluginsmanager /server/tools/pluginsmanager
        ln -s /core/x2t /server/tools/x2t
EOF

    # Run the docservice binary as the container's entrypoint
    ENTRYPOINT [ "npx", "cross-env", "NODE_ENV=development-linux", "NODE_CONFIG_DIR=/server/config", "/server/docservice" ]


    # COPY --from=build-fonts /build/deploy/AllFonts-web.js /var/www/onlyoffice/documentserver/sdkjs/common/AllFonts.js
    # COPY --from=build-fonts /build/deploy/AllFonts.js /var/www/onlyoffice/documentserver/server/FileConverter/bin/AllFonts.js
    # COPY --exclude=.git core-fonts /var/www/onlyoffice/documentserver/core-fonts
