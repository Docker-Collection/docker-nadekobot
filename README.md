# Docker Nadekobot

A rebuild [Nadekobot](https://gitlab.com/Kwoth/nadekobot) image for arm.

Original Dockerfile on NadekoBotV4, for normal x86_64 docker!

## Docker Compose

Nadekobot Docker Guide: [Link](https://nadekobot.readthedocs.io/en/v4/guides/docker-guide/)

```yml
version: "3"

services:
  nadeko:
    image: ghcr.io/docker-collection/nadekobot:4.3.8
    depends_on:
      - redis
    environment:
      TZ: Europe/Paris
      NadekoBot_RedisOptions: redis,name=nadeko
      #NadekoBot_ShardRunCommand: dotnet
      #NadekoBot_ShardRunArguments: /app/NadekoBot.dll {0} {1}
    volumes:
      - /srv/nadeko/conf/creds.yml:/app/creds.yml:ro
      - /srv/nadeko/data:/app/data

  redis:
    image: redis:7.0.5-alpine
    sysctls:
      - net.core.somaxconn=511
    command: redis-server --maxmemory 32M --maxmemory-policy volatile-lru
    volumes:
      - /srv/nadeko/redis-data:/data
```
