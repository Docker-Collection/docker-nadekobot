# Docker Nadekobot

~~A rebuild [Nadekobot](https://gitlab.com/Kwoth/nadekobot) image for arm.~~

~~Original Dockerfile on NadekoBotV4, for normal x86_64 docker!~~

Current can't build arm64 image.

## Docker Compose

Nadekobot Docker Guide: [Link](https://nadekobot.readthedocs.io/en/v5/guides/docker-guide/)

```yml
services:
  nadeko:
    image: ghcr.io/docker-collection/nadekobot:latest
    container_name: nadeko
    restart: unless-stopped
    environment:
      TZ: Europe/Rome
    volumes:
      - /opt/stacks/nadekobot/conf/creds.yml:/app/data/creds.yml
      - /opt/stacks/nadekobot/data:/app/data
networks: {}
```
