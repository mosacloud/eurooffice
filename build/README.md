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

## Development Builds

Once inside the container (`docker exec -it eo bash`), the following make targets are available:

### web-apps


#### Full web-apps build

includes npm ci, **run this first**

```sh
make web-apps
```

#### Quick rebuild
without npm ci, imagemin, or babel

```sh
make web-apps-dev
```

#### Quick rebuild with Nextcloud theme

```sh
make web-dev-nx
````

#### Custom build
Use `CFLAGS` to pass additional flags

```sh
THEME=nextcloud make web-apps-dev CFLAGS="--skip-imagemin"
````
> The make build commands clear the cache, this does not.
> Therefore you must run `/usr/bin/documentserver-flush-cache.sh`

### sdkjs

#### Full sdkjs build
includes npm install + closure compiler + allfontsgen
```shell
make sdkjs
````

