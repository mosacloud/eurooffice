# Euro-Office Document Server

Docker image where we are experimenting with building the OnlyOffice Document Server.

## Building the Image

First, clone the repositories for the core-fonts, sdkjs, web-apps, and server components:

```sh
git clone --recurse-submodules https://github.com/Euro-Office/fork.git
```

If the repo was cloned without --recurse-submodules, initialize and download the submodules with:
```sh
git submodule update --init --recursive
```

Then, you can build the full image by running:

```sh
cd fork/build
make build-image
```

or the development image with:

```sh
cd fork/build
make build
```

If you only want to build one of the components, you can specify the respective target:

```sh
make docker-target TARGET=sdkjs
```

## Running the Container

After building the image, you can run it with a simple `docker run` or with:

```sh
make run
```

If the docker build stockes because of broken content in cache, for example with error:
```sh
> Skipping ICU (done already).
> Skipping OpenSSL (done already).
> cannot change to '/build-cache1/third_party/workdir/icu/icu': No such file or directory
```
pruning the docker build cache might help:
```sh
docker builder prune -a
```