# silky-docker
Docker environment for [Silky](https://github.com/dhoelzer/Silky)

This environment is designed to run in a Docker container on the same
server where the SiLK data directory exists, or anywhere else where
the SiLK data directory is exposed as a file system.

The Dockerfile will install SiLK on Ubuntu 18:04, as its executable
files are required for Silky to run. Then it will install and run
Silky.

## Useful environment variables
Your Docker image should use the same versions of the SiLK tools as
your live installation. Consult the [CERT NetSA Security Suite
Monitoring web site](https://tools.netsa.cert.org/index.html) for
updated versions.

The Dockerfile accepts the following environment variables. While all
may be used at build time, only SILKY_PORT is useful when running the
image.

* FIXBUF  
The version of libfixbuf you wish to build SiLK with.
* YAF  
The version of yaf you wish to build SiLK with.
* SILK  
The version of SiLK you wish to build.
* SILKDATADIR  
SiLK's data directory (defaults to /data).
* SILKY_PORT  
The TCP port Silky will listen on (defaults to 3000).

## Building the image
This is how to build the image, with sample values for all build arguments:
```
sudo docker build \
  --build-arg FIXBUF=2.2.0 \
  --build-arg YAF=2.10.0 \
  --build-arg SILK=3.18.0 \
  --build-arg SILKDATADIR=/tmp/data \
  --build-arg SILKY_PORT=5000 \
  -t silky-docker .
```

Another example:
```
sudo docker build \
  --build-arg SILKDATADIR=/srv/silk/data \
  --build-arg SILKY_PORT=3001 \
  -t silky-docker .
```

## Starting the container
This is how the container is started, starting Silky on (non-default)
TCP port 3001 and exposing it on the docker host. The target directory
must equal the SILKDATADIR variable set at build time. In this
example, the container mounts the local file system's `/data/` into
the container's `/tmp/data/` directory.
```
sudo docker run \
  -p 5000:5000 \
  -e SILKY_PORT=5000 \
  --mount type=bind,source=/data,target=/tmp/data,readonly \
  -d silky-docker
```

or
```
sudo docker run \
  -p 3001:3001 \
  -e SILKY_PORT=3001 \
  --mount type=bind,source=/srv/silk/data,target=/srv/silk/data,readonly \
  -d silky-docker
```

## Apache reverse proxy configuration
Because Silky's websocket connections default to port 80, Silky can't
easily be run on an arbitrary port. One workaround is to place a
reverse HTTP proxy in front. The example below, for Apache 2, uses a
dedicated virtualhost ("silky.example.com") for the Silky
installation. Note the non-default port of 3001.

```
<VirtualHost your.ip:80>
    ServerName silky.example.com
    ServerAlias silky
    ErrorLog ${APACHE_LOG_DIR}/silky.example.com-error.log
    CustomLog ${APACHE_LOG_DIR}/silky.example.com-access.log combined

    ProxyPreserveHost On
    RequestHeader set X-Forwarded-Proto "http"
    ProxyPass / http://127.0.0.1:3001/ upgrade=ANY
    ProxyPassReverse / http://127.0.0.1:3001/

    RewriteEngine on
    RewriteCond %{HTTP:UPGRADE} ^WebSocket$ [NC]
    RewriteCond %{HTTP:CONNECTION} Upgrade [NC]
    RewriteRule .* ws://127.0.0.1:3001%{REQUEST_URI} [P]

</VirtualHost>
```

