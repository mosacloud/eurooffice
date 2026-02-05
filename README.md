# fork
Internal repo to document and organize our attempts

## Mirroring of OO repos

We mirror a subset of the official ONLYOFFICE repos to Euro-Office GitHub organization. Additional repos can be added in the workflow file [`.github/workflows/updatemirror.yml`](.github/workflows/updatemirror.yml) and the repo can be setup with [scripts/mirror.sh](scripts/mirror.sh). A personal access token is added to this repo as secret `EURO_OFFICE_MIRROR_TOKEN` to allow pushing to the Euro-Office organization which requires repo and workflow permissions.

## Using private container registry

For now the pre-built container images are on a private registry. In order to pull from it you need to generate a GitHub personal access token and use it with docker:

- Generate a PAT: https://github.com/settings/tokens/new?description=ghcr.io%20access%20for%20private%20packages&scopes=read:packages
- Authenticate your local docker agent: `docker login ghcr.io`
