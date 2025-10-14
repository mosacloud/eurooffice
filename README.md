# fork
Internal repo to document and organize our attempts

## Mirroring of OO repos

We mirror a subset of the official ONLYOFFICE repos to Euro-Office GitHub organization. Additional repos can be added in the workflow file [`.github/workflows/updatemirror.yml`](.github/workflows/updatemirror.yml) and the repo can be setup with [scripts/mirror.sh](scripts/mirror.sh). A personal access token is added to this repo as secret `EURO_OFFICE_MIRROR_TOKEN` to allow pushing to the Euro-Office organization which requires repo and workflow permissions.