<!--
SPDX-FileCopyrightText: 2026 Euro-Office contributors
SPDX-License-Identifier: AGPL
-->

> ## 🟦 Mosa fork
>
> This is **mosacloud's fork** of [Euro-Office/DocumentServer](https://github.com/Euro-Office/DocumentServer)
> (itself an OnlyOffice DocumentServer fork). Remotes follow the mosa convention:
> `origin` = `mosacloud/eurooffice`, `upstream` = `Euro-Office/DocumentServer`.
>
> **Why it exists:** to run Euro-Office as a **lean, per-tenant WOPI editor** behind
> Mosa Drive. The bundled all-in-one `standalone` image ships its own
> Postgres/Redis/RabbitMQ in-pod (~580 MiB idle) — too heavy to multiply per tenant.
> We instead run the **orchestrated** image (`cluster-docs`: docservice + converter +
> proxy, external infra), so each tenant is a light pod (~300 MiB idle) sharing
> namespaced Postgres/Redis and a tiny in-pod broker.
>
> **What's different from upstream:**
> - `build/.docker/orchestrated.bake.Dockerfile`: restored the `document-formats` COPY
>   (upstream commented it out — without it WOPI discovery has no edit actions and a
>   WOPI host can't route any file to the editor).
> - `.github/workflows/docker-hub.yml`: builds the lean `cluster` group and publishes
>   `mosacloud/eurooffice-cluster-{docs,utils,example}` to Docker Hub.
>
> Everything below is the upstream Euro-Office README.

---

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
