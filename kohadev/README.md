## Kohadev README

This Docker image is a complete Koha development install setup from git source.

It is very simple to setup and ready for use.

Also installed with bugzilla and qa-tools

## Install

`make` will setup Vagrant box and do a default install, build and run

`make upgrade` pulls the latest build image from Docker registry hub.

`make browser` runs a browser inside Vagrant box for testing

`make logs-f` runs a tail on logs inside container

## Advanced Usage

All environment variables used in setup can be overridden. Complete list is in Dockerfile.

Example using makefile:

```
KOHA_ADMINUSER="superadmin" KOHA_ADMINPASS="superpass" AUTHOR_NAME='"Roger Rabbit"' AUTHOR_EMAIL="rabbit@mail.com" BUGZ_USER="rabbit@mail.com" BUGZ_PASS=77rafi make run
```

Example from inside Vagrant box:

```
sudo docker run -d --name kohadev_docker \
  -p 80:80 -p 8080:8080 -p 8081:8081 \
  -e KOHA_ADMINUSER="superadmin" \
  -e KOHA_ADMINPASS="superpass" \
  -e AUTHOR_NAME="Roger Rabbit" \
  -e AUTHOR_EMAIL=rabbit@mail.com \
  -e BUGZ_USER=rabbit@mail.com \
  -e BUGZ_PASS=rabbitz \
  -t digibib/kohadev
```