# Bring in the upstream OnlyOffice Document Server image so that
# we can extract things from it later
FROM onlyoffice/documentserver:latest AS upstream


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


#### BUILD SDKJS COMPONENT ####
FROM base AS sdkjs

COPY ./sdkjs /sdkjs

WORKDIR /sdkjs/build

RUN <<EOF
npm install
grunt
EOF


#### BUILD WEB-APPS COMPONENT ####
FROM base AS web-apps 

COPY ./web-apps /web-apps

WORKDIR /web-apps/build

RUN <<EOF
./sprites.sh
npm install
grunt
EOF


#### BUILD SERVER COMPONENT ####
FROM base AS server

ADD ./server /server

WORKDIR /server/Common
RUN npm install

# DocService
WORKDIR /server/DocService
RUN <<EOF
npm install
pkg . -t linux-x64 --options max_old_space_size=4096 -o /server/build/docservice
EOF

# FileConverter
# TODO: This component requires x2t at runtime in order to work fully
WORKDIR /server/FileConverter
RUN <<EOF
npm install
pkg . -t linux-x64 --options max_old_space_size=4096 -o /server/build/fileconverter
EOF

# Metrics
WORKDIR /server/Metrics
RUN <<EOF
npm install
pkg . -t linux-x64 --options max_old_space_size=4096 -o /server/build/metrics
EOF

# AdminPanel
WORKDIR /server/AdminPanel/server
RUN <<EOF
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
COPY --exclude=.git core-fonts /var/www/onlyoffice/documentserver/core-fonts

COPY --from=sdkjs /sdkjs/deploy/sdkjs /var/www/onlyoffice/documentserver/sdkjs
COPY --from=web-apps /web-apps/deploy/web-apps /var/www/onlyoffice/documentserver/web-apps

COPY ./onlyoffice.github.io/sdkjs-plugins /sdkjs-plugins


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