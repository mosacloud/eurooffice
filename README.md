# Euro-Office Document Server

Meta-repository for building and developing the Euro-Office Document Server — a fork of ONLYOFFICE Document Server. Contains CI/CD configuration, build infrastructure, and development tooling. Component source code lives in the git submodules.

## Components (submodules)

### `server` — Node.js backend

Microservice-style backend that ties everything together. Key services:

- **DocService** — real-time collaboration over WebSockets (Socket.io), backed by Redis (session state) and RabbitMQ (message bus)
- **FileConverter** — document format conversion; delegates to the native C++ binaries from `core`
- **AdminPanel** — configuration and system monitoring UI
- **Metrics** — StatsD-based performance metrics

### `web-apps` — Frontend editors

Vanilla JS (RequireJS modules) editors for document, spreadsheet, presentation, PDF, and Visio files. Built with Grunt: LESS → CSS, Babel transpilation, Terser minification. Theming is handled via `theme/<name>/` folders with a `config.json` for brand values and LESS overrides. The active theme is set with the `THEME` environment variable at build time (we use `euro-office`).

### `sdkjs` — JavaScript SDK

Client-side document model layer that runs inside the editors. Implements the Office Open XML APIs for Word, Excel, and PowerPoint documents (the `word/`, `cell/`, `slide/` directories), plus PDF annotation support. Built with Grunt and Google Closure Compiler.

### `core` — C++ rendering engine

High-performance native components for font rendering (FreeType), vector graphics (AGG), and format conversion between DOCX, PDF, EPUB, DjVu, FB2, XPS, RTF, ODF, and more (the `x2t` converter). Compiled with CMake; the resulting binaries are consumed by `server/FileConverter`.

### `core-fonts` — Font assets

Font files bundled with the document server to ensure consistent rendering across environments.

## Getting started

Clone with all submodules:

```sh
git clone --recurse-submodules https://github.com/Euro-Office/fork.git
```

Or, if already cloned without submodules:

```sh
git submodule update --init --recursive
```

## Building

See **[build/README.md](build/README.md)** for the full guide. Quick summary:

```sh
# Build the full Docker image
cd build && make build-image

# Build only one component
make docker-target TARGET=sdkjs

# Run the container
make run
```

## Development

See **[develop/README.md](develop/README.md)** for the full guide. Quick summary:

The `develop/` directory provides a Docker Compose environment with a pre-configured Nextcloud + Euro-Office stack for iterative development:

```sh
# Start the dev environment (uses locally available image)
cd develop && make

# Use the latest image from GitHub
make pull

# Build from scratch
make build
```

Once running, the server is at `http://localhost:8081/`. Enter the container to rebuild individual components:

```sh
docker compose exec eo bash
make web-apps    # or: make sdkjs, make core, make server
```

## Try out

to be added


## Infrastructure

- **Mirroring** — ONLYOFFICE upstream repos are mirrored automatically via [`.github/workflows/updatemirror.yml`](.github/workflows/updatemirror.yml). New repos can be added there; the `scripts/mirror.sh` script handles initial setup.
- **Container registry** — Pre-built images are on a private GitHub Container Registry. To pull them:
  - Generate a PAT: https://github.com/settings/tokens/new?description=ghcr.io%20access%20for%20private%20packages&scopes=read:packages
  - Authenticate your local docker agent: `docker login ghcr.io`
