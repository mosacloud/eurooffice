# Bring in the upstream OnlyOffice Document Server image so that
# we can extract things from it later
FROM onlyoffice/documentserver:latest AS upstream

FROM ubuntu AS core

ENV TZ=Etc/UTC
ENV DEBIAN_FRONTEND=noninteractive

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN apt -y update && \
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

RUN --mount=type=bind,source=./core,target=/core,rw <<EOF
cd /core
git checkout private/tbari/cmake-linux-build
cd /
mkdir /build
cd /build
cmake -G Ninja /core/X2tConverter/build/cmake
cmake --build .

# Collect all the shared libs into the package directory
mkdir package
cp ./x2t package/x2t
for lib in $(find . -name "*.so"); do cp $lib package/; done
cp /core/Common/3dParty/icu/install_linux_x64/lib/*.so* package/
EOF

# Debian 13 as the base image for building our components
FROM debian:trixie AS base

# Install base dependencies needed for all components
RUN <<EOF
apt update
apt install -y nodejs npm openjdk-21-jdk wget zip brotli

npm install -g @yao-pkg/pkg grunt-cli
EOF


#### BUILD FONTS ####
# We may not need this build step in the end as it can be
# generated on the fly on the document server using
# /usr/bin/documentserver-generate-allfonts.sh
FROM base AS fonts

WORKDIR /build

COPY --from=upstream /var/www/onlyoffice/documentserver/server/FileConverter/bin/* /build/
COPY --from=upstream /var/www/onlyoffice/documentserver/server/tools/allfontsgen /build/
RUN mkdir -p /build/deploy /build/core-fonts

COPY ./core-fonts /build/core-fonts
# RUN --mount=type=bind,source=core-fonts,target=/build/core-fonts \
RUN	./allfontsgen --input="/build/core-fonts" \
		--allfonts-web="/build/deploy/AllFonts-web.js" \
		--allfonts="/build/deploy/AllFonts.js" \
		--images="/build/deploy" \
		--output-web="/build/deploy" \
		--selection="/build/deploy/font_selection.bin"

FROM scratch AS fonts-output

COPY --from=fonts /build/deploy/AllFonts-web.js /AllFonts.js

#### BUILD SDKJS COMPONENT ####
FROM base AS sdkjs

RUN --mount=type=bind,source=./sdkjs,target=/temp,rw <<EOF
cd /temp/build
npm install
grunt

# The built files need to be accessible in other layers
cp -r /temp/deploy/sdkjs /sdkjs
EOF


#### BUILD WEB-APPS COMPONENT ####
FROM base AS web-apps 

RUN --mount=type=bind,source=./web-apps,target=/temp,rw <<EOF
export PRODUCT_VERSION="9.2.0"
cd /temp/build
./sprites.sh
npm install
grunt

# The built files need to be accessible in other layers
cp -r /temp/deploy/web-apps /web-apps
EOF


#### BUILD SERVER COMPONENT ####
FROM base AS server

# Common
RUN --mount=type=bind,source=./server,target=/server,rw <<EOF
cd /server/Common
npm install
EOF

# DocService
RUN --mount=type=bind,source=./server,target=/server,rw <<EOF
cd /server/DocService
npm install
pkg . -t linux-x64 --options max_old_space_size=4096 -o /server/build/docservice
EOF

# FileConverter
# TODO: This component requires x2t at runtime in order to work fully
RUN --mount=type=bind,source=./server,target=/server,rw <<EOF
cd /server/FileConverter
npm install
pkg . -t linux-x64 --options max_old_space_size=4096 -o /server/build/fileconverter
EOF

# Metrics
RUN --mount=type=bind,source=./server,target=/server,rw <<EOF
cd /server/Metrics
npm install
pkg . -t linux-x64 --options max_old_space_size=4096 -o /server/build/metrics
EOF

# AdminPanel
RUN --mount=type=bind,source=./server,target=/server,rw <<EOF
cd /server/AdminPanel/server
npm install
pkg . -t linux-x64 --options max_old_space_size=4096 -o /server/build/adminpanel
EOF

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
