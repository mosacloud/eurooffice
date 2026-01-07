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
docker build -t euro-office/documentserver:latest --build-arg PRODUCT_VERSION=9.2.1 --target finalupstream -f ./Dockerfile ../../
```

If you only want to build one of the components, you can specify the respective target:

```sh
docker build -t euro-office/documentserver:latest --build-arg PRODUCT_VERSION=9.2.1 --target sdkjs -f ./Dockerfile ../../
```

## Development environment

The docker compose environemnt in this directory allows to run document server built from our code base.

```
docker compose up -d
```

Currently it requires you to use the container ip address, localhost does not work. You can use the /example endpoint for testing or connect it with the included Nextcloud container.

To not require to rebuild all component and just work on specific areas, you can mount the deploy/ directory of web-apps or sdkjs to the container. That way you can build locally with grunt and have your files deployed in the container directly.

AllFonts.js is missing in sdkjs (still requires some work), the easiest way to get this is:

```
DEPLOY=../../sdkjs/deploy/sdkjs TARGET=fonts-output make docker-target
```

## Running the Container

After building the image, you can run it with a simple `docker run` command. The only caveat is that you also need to mount the `local.json` file as a volume so some of the config values can be overridden:

```sh
$ docker run --rm \
      --add-host host.docker.internal=host-gateway \
      -v ./local.json:/server/config/local.json \
      euro-office/documentserver:latest
```

**Note:** You also need to be running RabbitMQ and a database server alongside this container.
