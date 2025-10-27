# Regarding new builds

## Actual useful documentation

You can find all the hassles we had to deal with in the [development_logs](https://github.com/btactic-oo/unlimited-onlyoffice-package-builder/tree/main/development_logs) folder.

You can check information on the VPS requisites in order to build OnlyOffice in (README-BUILD-NEWER-VERSIONS.md v0.0.5)[https://github.com/btactic-oo/unlimited-onlyoffice-package-builder/blob/v0.0.5/README-BUILD-NEWER-VERSIONS.md].

- The [latest web-apps commit](https://github.com/btactic-oo/web-apps/commit/9643650eee79d14ebdadbe10dbd413bb08ee549c).
- The [latest server commit](https://github.com/btactic-oo/server/commit/3052bef2739f637ffa5abaec242c27f1fa733707).

- In order to build onlyoffice with a custom organization they have eased it a lot.
Just make sure to have a remoted named 'origin' that points to your forked organization, not to original one.
Also force the git protocol to be ssh.

**Note:** If we want the public to build against our fork instead of OnlyOffice when they do not enforce git protocol to be ssh, well, we would need to modify [git_update function](https://github.com/ONLYOFFICE/build_tools/blob/v9.2.0.25/scripts/base.py#L567-L568) on `scripts/base.py` from build_tools. Because I'm not sure how you would modify *git_owner* value there in an easy way.

**Note:** I have not actually tested this call below enforcing the git protocol to be ssh.

```bash
  UPSTREAM_ORGANIZATION="Euro-Office"
  _OUT_FOLDER="out"
  _PRODUCT_VERSION="9.0.4"
  _BUILD_NUMBER="52"

  _UPSTREAM_TAG="v${_PRODUCT_VERSION}.${_BUILD_NUMBER}"
  _UNLIMITED_ORGANIZATION_TAG="${_UPSTREAM_TAG}${_TAG_SUFFIX}"

  git clone \
    --depth=1 \
    --recursive \
    --branch ${_UPSTREAM_TAG} \
    https://github.com/${UPSTREAM_ORGANIZATION}/build_tools.git \
    build_tools
  # Ignore detached head warning
  cd build_tools
  mkdir ${_OUT_FOLDER}
  docker build --tag onlyoffice-document-editors-builder .
  docker run -e PRODUCT_VERSION=${_PRODUCT_VERSION} -e BUILD_NUMBER=${_BUILD_NUMBER} -e NODE_ENV='production' -v $(pwd)/${_OUT_FOLDER}:/build_tools/out onlyoffice-document-editors-builder /bin/bash -c '\
    cd tools/linux && \
    python3 ./automate.py --branch=tags/'"${_UPSTREAM_TAG} --git-protocol=ssh"
  cd ..
```

---

Compare what it's shown above with all of the workarounds we needed to do in the past in order to [fetch two specific repos from outside the onlyoffice repo](https://github.com/btactic-oo/build_tools/commit/f88a3ba5470664888bbf150d67ef0b31f74a6cbb), ([more simple approach 1/2](https://github.com/btactic-oo/build_tools/commit/2e42e83151bd11609c1d2fbaabcc3f0f7b587497), [more simple approach 1/2](https://github.com/btactic-oo/build_tools/commit/7da607da885285fe3cfc9feaf37b1608666039eb)). It was either patching build_tools directly to check those repos and switching the organization or, lately, [removing actual tags from onlyoffice and replacing with our own patched ones](https://github.com/btactic-oo/unlimited-onlyoffice-package-builder/blob/v0.0.5/onlyoffice-package-builder.sh#L182-L194) which didn't involve patching build_tools at all.

---

Finally check what [onlyoffice-package-builder.sh](https://github.com/btactic-oo/unlimited-onlyoffice-package-builder/blob/v0.0.5/onlyoffice-package-builder.sh) and [onlyoffice-deb-builder.sh](https://github.com/btactic-oo/unlimited-onlyoffice-package-builder/blob/v0.0.5/deb_build/onlyoffice-deb-builder.sh) scripts do.

## Current status on the unlimited build

You can check on the [Feedback on README-BUILD-NEWER-VERSIONS.md (v0.0.5)](https://github.com/btactic-oo/unlimited-onlyoffice-package-builder/issues/4) issue latest comments that the usual cherry-picked commits no longer work in recent versions such as **9.1.0.168**.

This is usual stuff when trying to keep on with OnlyOffice. This only affects server repo but, back in the day, it affected every now and then to the build_tools repo. In these days of copy-and-paste and LLMs it's not easy to receive useful commits or patches that fixes the problem even if it's a quite easy to solve.

Or maybe my our latest documentation on how to build newer versions of OnlyOffice it's not good enough and needs some improvement. In any case I suspect some people try to reuse their old build directories instead of starting from scratch.
