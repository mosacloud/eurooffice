# ==============================================================================
# MODULE DOCKERFILE
# This file is not meant to be built standalone. It is consumed by the 
# docker-bake.hcl files in the parent monorepos.
#
# REQUIRED CONTEXTS:
# - server: builds from server repo
# - core: builds from core repo
# - web-apps: builds from web-apps repo
# - sdkjs: builds from sdkjs repo
# - example: builds from example repo
# ==============================================================================

#### PACKAGE ####
# Extends finalubuntu (or a pre-built image via PACKAGE_BASE); installs packaging tools, then runs build-packages.sh
# to populate /build/package/out/ and invoke the upstream Makefile.

ARG PACKAGE_BASE

FROM ${PACKAGE_BASE} AS package
ARG PRODUCT_VERSION
ARG BUILD_NUMBER=0

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        devscripts dpkg-dev build-essential fakeroot debhelper \
        rpm m4 curl ca-certificates gnupg symlinks && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g @yao-pkg/pkg && \
    rm -rf /var/lib/apt/lists/*

# Upstream packaging repo
COPY document-server-package/ /document-server-package/

# Original server source files required by the upstream Makefile's sed transforms
COPY server/Common/config/ /server-src/Common/config/
COPY server/schema/        /server-src/schema/
COPY server/license/       /server-src/license/
COPY server/LICENSE.txt    /server-src/
COPY server/3rd-Party.txt  /server-src/

COPY --chmod=755 build/scripts/build-packages.sh /build-packages.sh

ENV PRODUCT_VERSION=${PRODUCT_VERSION}
ENV BUILD_NUMBER=${BUILD_NUMBER}

RUN /build-packages.sh


#### PACKAGES OUTPUT ####
# Scratch stage so `docker build --target packages -o <dir>` extracts only
# the finished .deb and .rpm files.
FROM scratch AS packages
COPY --from=package /packages/ /