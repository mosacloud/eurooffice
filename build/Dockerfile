# Bring in the upstream OnlyOffice Document Server image so that
# we can extract things from it later
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
        cmake -GNinja -DEO_CORE_OUTPUT_DIR=/core_binaries /core
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
        grunt --skip-imagemin && \
        cp -r /temp/deploy/web-apps /web-apps

FROM scratch AS web-apps
    ARG PRODUCT_VERSION
    
    COPY --from=build-web-apps /web-apps /web-apps



#### SERVER ####
FROM base AS build-server
    RUN --mount=type=bind,source=./server,target=/temp,rw \
        mkdir /server && \
        cd /temp/Common && \
        npm install && \
        #### DOCSERVICE ####
        cd /temp/DocService && \
        npm install && \
        pkg . -t linux-x64 --options max_old_space_size=4096 -o /server/docservice && \
        #### FILECONVERTER ####
        cd /temp/FileConverter && \
        npm install && \
        pkg . -t linux-x64 --options max_old_space_size=4096 -o /server/fileconverter && \
        #### METRICS ####
        cd /temp/Metrics && \
        npm install && \
        pkg . -t linux-x64 --options max_old_space_size=4096 -o /server/metrics && \
        #### ADMINPANEL ####
        cd /temp/AdminPanel/server && \
        npm install && \
        pkg . -t linux-x64 --options max_old_space_size=4096 -o /server/adminpanel && \
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

    COPY --from=server /server/docservice /var/www/onlyoffice/documentserver/docservice
    COPY --from=server /server/fileconverter /var/www/onlyoffice/documentserver/server/fileconverter
    COPY --from=server /server/metrics /var/www/onlyoffice/documentserver/metrics
    COPY --from=server /server/adminpanel /var/www/onlyoffice/documentserver/adminpanel

    RUN sed 's,autostart=false,autostart=true,' -i /etc/supervisor/conf.d/ds-example.conf

    # COPY ./onlyoffice.github.io/sdkjs-plugins /sdkjs-plugins


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
