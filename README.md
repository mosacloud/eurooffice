<!--
SPDX-FileCopyrightText: 2026 Euro-Office contributors
SPDX-License-Identifier: AGPL
-->

[![License](https://img.shields.io/badge/License-GNU%20AGPL%20V3-green.svg?style=flat)](https://www.gnu.org/licenses/agpl-3.0.en.html)

# Euro-Office
**Your sovereign office**

[Learn more.](https://github.com/Euro-Office/)

## Get involved
Get involved! You can file issues, propose pull requests and more. We are looking forward to make the digital sovereign office space better than ever before!

### Try out
We currently provide a docker image for testing and integration purposes. We are going to publish deb/rpm packages shortly.

```
docker pull ghcr.io/euro-office/documentserver:latest
docker run -i -t -d -p 8080:80 --restart=always -e EXAMPLE_ENABLED=true -e JWT_SECRET=my_jwt_secret ghcr.io/euro-office/documentserver:latest
```

### Building

Our build steps and processes are documented in https://github.com/Euro-Office/DocumentServer/tree/main/build. For development there are more detailed steps to build and run individual components in https://github.com/Euro-Office/DocumentServer/tree/main/develop 


# Document Server — Debian/Ubuntu Installation Guide

This guide describes how to install the Document Server `.deb` package on a
standalone Ubuntu host. The steps mirror our official Docker image, with the
container-only pieces removed (see [Differences from the Docker image](#differences-from-the-docker-image)).

## System requirements

- **OS:** Ubuntu 24.04 LTS
- **Architecture:** `amd64` or `arm64` — download the build matching your host.
  Check yours with `dpkg --print-architecture`.
- **Privileges:** root / `sudo` access.

The package depends on a PostgreSQL database, a Redis cache, and a RabbitMQ
message broker. In this guide they all run locally on the same host; you can
point the package at remote instances by changing the connection values in
[Step 3](#step-3-pre-seed-the-database-configuration).

## Step 1: Install dependencies

Install the runtime services and the utilities the package's scripts rely on:

```bash
sudo apt-get update
ACCEPT_EULA=Y sudo apt-get install -y \
    postgresql postgresql-client redis-server rabbitmq-server \
    nginx nginx-extras supervisor sudo gdb jq util-linux \
    netcat-openbsd xxd openssl
```

On a standard systemd-based Ubuntu install, PostgreSQL, Redis, RabbitMQ, and
Nginx are started automatically once installed. Confirm they are running before
continuing:

```bash
sudo systemctl status postgresql redis-server rabbitmq-server nginx
```

## Step 2: Create the PostgreSQL user and database

The package connects to PostgreSQL using the credentials you supply in the next
step. Create the matching role and database first:

```bash
sudo -u postgres psql -c "CREATE USER eurooffice WITH PASSWORD 'eurooffice';"
sudo -u postgres psql -c "CREATE DATABASE eurooffice OWNER eurooffice;"
```

> **Production note:** `eurooffice` / `eurooffice` are the defaults used by our
> ephemeral Docker image. For a real deployment, choose a strong password and
> use it consistently here and in Step 3.

## Step 3: Pre-seed the database configuration

Installing the package triggers a debconf prompt for the database connection.
You can answer it interactively, or pre-seed the answers for an unattended
install. Set `PKG_NAME` to the **Debian package name** (the `Package:` field of
the `.deb`, not the filename):

```bash
PKG_NAME="documentserver"   # replace with the actual package name

echo "$PKG_NAME ds/db-type string postgres"    | sudo debconf-set-selections
echo "$PKG_NAME ds/db-host string localhost"   | sudo debconf-set-selections
echo "$PKG_NAME ds/db-port string 5432"        | sudo debconf-set-selections
echo "$PKG_NAME ds/db-user string eurooffice"  | sudo debconf-set-selections
echo "$PKG_NAME ds/db-pwd password eurooffice" | sudo debconf-set-selections
echo "$PKG_NAME ds/db-name string eurooffice"  | sudo debconf-set-selections
```

If you skip this step, `apt` will prompt you for the same six values during
installation.

## Step 4: Download the package

Download the build that matches your version, build number, and architecture:

```bash
wget http://xyz.com/version/build/package.deb -O documentserver.deb
```

Replace `version` and `build` in the URL with the release you are installing.

## Step 5: Install the package

```bash
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ./documentserver.deb
```

`apt-get install` (rather than `dpkg -i`) is used so any remaining package
dependencies are resolved automatically. During installation the package's
post-install scripts initialize the database schema and configure the local
services.

> Do **not** set `DS_DOCKER_INSTALLATION=true` for a standalone install. That
> flag is only for our Docker build, where service start-up and schema setup are
> handled by the container instead of the package.

## Step 6: Flush the cache

After installation, clear any stale cache so the server starts cleanly:

```bash
sudo documentserver-flush-cache.sh -r false
```

## Verify the installation

Nginx serves the Document Server once installation completes. Browse to the
host (for example `http://<server-ip>/`) to confirm the welcome/example page
loads. You can also tail the logs under `/var/log/<company>/<product>/`.

## Troubleshooting

**Database schema was not created.** If the post-install step did not populate
the schema, run it manually with the same credentials from Step 3:

```bash
sudo -u postgres PGPASSWORD=eurooffice \
    psql -h localhost -U eurooffice -d eurooffice \
    -f /var/www/<company>/<product>/server/schema/postgresql/createdb.sql
```

Replace `<company>/<product>` with your install root (the package installs
under `/var/www/<company>/<product>`).

**Connection failures.** Verify PostgreSQL, Redis, and RabbitMQ are running and
reachable on `localhost` (Step 1), and that the debconf values from Step 3 match
the role and database created in Step 2.

## Differences from the Docker image

If you are comparing this guide to our `Dockerfile`, the following container-only
steps are intentionally omitted for a standalone install:

- **`DS_DOCKER_INSTALLATION=true`** — set only in the image so the package skips
  container-managed setup. Leave it unset here.
- **Supervisor configs and `entrypoint.sh`** — the image runs processes under
  supervisor via a custom entrypoint. On a standard host, the package's own
  service configuration manages the processes; you do not copy these files.
- **Manual `service ... start` calls** — needed in the image because Docker has
  no init system. On systemd-based Ubuntu the services start automatically.

