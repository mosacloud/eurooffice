# Euro-Office Document Server

Docker image where we are experimenting with building the OnlyOffice Document Server.

## Building the Image

First, clone the repositories for the core-fonts, sdkjs, web-apps, and server components:

```sh
$ git clone https://github.com/Euro-Office/core-fonts.git
$ git clone https://github.com/Euro-Office/sdkjs.git
$ git clone https://github.com/Euro-Office/web-apps.git
$ git clone https://github.com/Euro-Office/server.git
```

Then, you can build the full image by running:

```sh
$ docker buildx build . -t euro-office/documentserver:latest
```

If you only want to build one of the components, you can specify the respective target:

```sh
$ docker buildx build . -t euro-office/documentserver:latest --target sdkjs
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
