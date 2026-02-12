# Euro-Office Document Server

Docker image where we are experimenting with building the OnlyOffice Document Server.

## Building the Image

First, clone the repositories for the core-fonts, sdkjs, web-apps, and server components:

```sh
git clone https://github.com/Euro-Office/fork.git
git clone https://github.com/Euro-Office/core.git
git clone https://github.com/Euro-Office/core-fonts.git
git clone https://github.com/Euro-Office/sdkjs.git
git clone https://github.com/Euro-Office/web-apps.git
git clone https://github.com/Euro-Office/server.git
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
