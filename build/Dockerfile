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

    RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
        apt -y update && \
        apt -y upgrade && \
        apt -y install \
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
        rm -rf /var/lib/apt/lists/*

    RUN --mount=type=bind,source=./core,target=/core,rw \
        cd /core && \
        mkdir build && \
        cd build && \
        cmake -G Ninja /core/X2tConverter/build/cmake && \
        cmake --build -j $(nproc) . && \
        mkdir package && \
        cp ./x2t package/x2t && \
        for lib in $(find . -name "*.so"); do cp $lib package/; done && \
        cp /core/Common/3dParty/icu/install_linux_x64/lib/*.so* package/



#### FONTS ####
# We may not need this build step in the end as it can be
# generated on the fly on the document server using
# /usr/bin/documentserver-generate-allfonts.sh
FROM base AS build-fonts
    WORKDIR /build

    COPY --from=upstream /var/www/onlyoffice/documentserver/server/FileConverter/bin/* /build/
    COPY --from=upstream /var/www/onlyoffice/documentserver/server/tools/allfontsgen /build/
    RUN mkdir -p /build/deploy /build/core-fonts

    RUN --mount=type=bind,source=core-fonts,target=/build/core-fonts \
        ./allfontsgen --input="/build/core-fonts" \
		    --allfonts-web="/build/deploy/AllFonts-web.js" \
		    --allfonts="/build/deploy/AllFonts.js" \
		    --images="/build/deploy" \
		    --output-web="/build/deploy" \
		    --selection="/build/deploy/font_selection.bin"

FROM scratch AS fonts
    COPY --from=build-fonts /build/deploy/AllFonts-web.js /AllFonts.js



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
    RUN --mount=type=bind,source=./web-apps,target=/temp,rw \
        export PRODUCT_VERSION="9.2.0" && \
        cd /temp/build && \
        npm install && \
        grunt && \
        cp -r /temp/deploy/web-apps /web-apps

FROM scratch AS web-apps
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
        pkg . -t linux-x64 --options max_old_space_size=4096 -o /server/adminpanel

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

COPY --from=fonts /build/deploy/AllFonts-web.js /var/www/onlyoffice/documentserver/sdkjs/common/AllFonts.js
COPY --from=fonts /build/deploy/AllFonts.js /var/www/onlyoffice/documentserver/server/FileConverter/bin/AllFonts.js
COPY --from=fonts /build/core-fonts /var/www/onlyoffice/documentserver/core-fonts

COPY --from=sdkjs /sdkjs /var/www/onlyoffice/documentserver/sdkjs
COPY --from=web-apps /web-apps /var/www/onlyoffice/documentserver/web-apps

COPY --from=core /core/build/package/* /var/www/onlyoffice/documentserver/server/FileConverter/bin/

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
COPY --from=sdkjs /sdkjs/deploy/sdkjs /sdkjs
COPY --from=web-apps /web-apps/deploy/web-apps /web-apps
COPY --from=server /server/build/* /server/

# Copy the configuration files from the server component
COPY --from=server /server/Common/config /server/config

# Copy over tool components from the upstream image
COPY --from=upstream /var/www/onlyoffice/documentserver/server/tools/allfontsgen /server/tools/allfontsgen
COPY --from=upstream /var/www/onlyoffice/documentserver/server/tools/allthemesgen /server/tools/allthemesgen
COPY --from=upstream /var/www/onlyoffice/documentserver/server/tools/pluginsmanager /server/tools/pluginsmanager

# Run the docservice binary as the container's entrypoint
ENTRYPOINT [ "npx", "cross-env", "NODE_ENV=development-linux", "NODE_CONFIG_DIR=/server/config", "/server/docservice" ]


#COPY --from=build-fonts /build/deploy/AllFonts-web.js /var/www/onlyoffice/documentserver/sdkjs/common/AllFonts.js
#COPY --from=build-fonts /build/deploy/AllFonts.js /var/www/onlyoffice/documentserver/server/FileConverter/bin/AllFonts.js
#COPY --exclude=.git core-fonts /var/www/onlyoffice/documentserver/core-fonts
