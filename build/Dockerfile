# Bring in the upstream OnlyOffice Document Server image so that
# we can extract things from it later
FROM onlyoffice/documentserver:latest AS oo-base


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

COPY --from=oo-base /var/www/onlyoffice/documentserver/server/FileConverter/bin/* /build/
COPY --from=oo-base /var/www/onlyoffice/documentserver/server/tools/allfontsgen /build/
RUN mkdir -p /build/deploy /build/core-fonts

COPY ./core-fonts /build/core-fonts
# RUN --mount=type=bind,source=core-fonts,target=/build/core-fonts \
RUN	./allfontsgen --input="/build/core-fonts" \
		--allfonts-web="/build/deploy/AllFonts-web.js" \
		--allfonts="/build/deploy/AllFonts.js" \
		--images="/build/deploy" \
		--output-web="/build/deploy" \
		--selection="/build/deploy/font_selection.bin"


FROM base AS build-sdkjs

RUN apt-get install -y grunt
RUN mkdir -p /build/sdkjs
COPY ./sdkjs /build/sdkjs

RUN cd /build/sdkjs/build && \
	npm install && \
	grunt


FROM base AS build-webapps

RUN apt-get install -y grunt
RUN mkdir -p /build/web-apps
COPY ./web-apps /build/web-apps

RUN cd /build/web-apps/build && \
	npm install && \
	grunt


# Stage for having a runnable image with document server by applying the built files
# Once we can build everything we can base on ubuntu and wrap up packaging
FROM oo-base AS final

COPY --from=build-fonts /build/deploy/AllFonts-web.js /var/www/onlyoffice/documentserver/sdkjs/common/AllFonts.js
COPY --from=build-fonts /build/deploy/AllFonts.js /var/www/onlyoffice/documentserver/server/FileConverter/bin/AllFonts.js
COPY --exclude=.git core-fonts /var/www/onlyoffice/documentserver/core-fonts

COPY --from=build-sdkjs /build/sdkjs/deploy /var/www/onlyoffice/documentserver/sdkjs
COPY --from=build-webapps /build/web-apps/deploy /var/www/onlyoffice/documentserver/web-apps

# Stage for targetting copying just the build files out
FROM scratch AS output

COPY --from=final /var/www/onlyoffice/documentserver /documentserver
