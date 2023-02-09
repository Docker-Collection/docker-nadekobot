FROM alpine:3.17.1@sha256:f271e74b17ced29b915d351685fd4644785c6d1559dd1f2d4189a5e851ef753a as nadeko-source

WORKDIR /nadeko

# renovate: datasource=gitlab-tags depName=Kwoth/nadekobot
ARG NADEKO_VERSION=4.3.11

RUN apk add git curl && \
    git clone https://gitlab.com/Kwoth/nadekobot.git --branch=${NADEKO_VERSION} . && \
    mkdir /app && \
    curl -L https://yt-dl.org/downloads/latest/youtube-dl -o /app/youtube-dl

FROM mcr.microsoft.com/dotnet/sdk:6.0@sha256:6e5af070e36c6cbd750952a54baca7b2224b9082ca282fad444a8c1a8a076c8d AS build
WORKDIR /source

COPY --from=nadeko-source /nadeko/src/Nadeko.Medusa/*.csproj src/Nadeko.Medusa/
COPY --from=nadeko-source /nadeko/src/Nadeko.Econ/*.csproj src/Nadeko.Econ/
COPY --from=nadeko-source /nadeko/src/Nadeko.Common/*.csproj src/Nadeko.Common/
COPY --from=nadeko-source /nadeko/src/NadekoBot/*.csproj src/NadekoBot/
COPY --from=nadeko-source /nadeko/src/NadekoBot.Coordinator/*.csproj src/NadekoBot.Coordinator/
COPY --from=nadeko-source /nadeko/src/NadekoBot.Generators/*.csproj src/NadekoBot.Generators/
COPY --from=nadeko-source /nadeko/src/ayu/Ayu.Discord.Voice/*.csproj src/ayu/Ayu.Discord.Voice/
COPY --from=nadeko-source /nadeko/NuGet.Config ./
RUN dotnet restore src/NadekoBot/

COPY --from=nadeko-source /nadeko/ .
WORKDIR /source/src/NadekoBot
RUN set -xe; \
    dotnet --version; \
    dotnet publish -c Release -o /app --no-restore; \
    mv /app/data /app/data_init; \
    rm -Rf libopus* libsodium* opus.* runtimes/win* runtimes/osx* runtimes/linux-arm* runtimes/linux-mips*; \
    find /app -type f -exec chmod -x {} \; ;\
    chmod +x /app/NadekoBot

# final stage/image
FROM mcr.microsoft.com/dotnet/runtime:6.0@sha256:1b3c4b5ea4b2f91b6b1b02f684372bc3c261ab9cb9deb252398f33830005efc5
WORKDIR /app

COPY --from=build /app ./
COPY --from=nadeko-source /nadeko/docker-entrypoint.sh /usr/local/sbin
COPY --from=nadeko-source /app/youtube-dl /usr/local/bin/youtube-dl

RUN set -xe; \
    useradd -m nadeko; \
    apt-get update; \
    apt-get install -y --no-install-recommends libopus0 libsodium23 libsqlite3-0 ffmpeg sudo; \
    rm -rf /var/lib/apt/lists/*; \
    echo 'Defaults>nadeko env_keep+="ASPNETCORE_* DOTNET_* NadekoBot_* shard_id total_shards TZ"' > /etc/sudoers.d/nadeko; \
    chmod +x /usr/local/bin/youtube-dl; \
    chmod +x /usr/local/sbin/docker-entrypoint.sh; \
    apt-get autoremove -y; \
    apt-get autoclean -y

ENV shard_id=0
ENV total_shards=1
ENV NadekoBot__creds=/app/data/creds.yml

VOLUME [ "/app/data" ]
ENTRYPOINT [ "/usr/local/sbin/docker-entrypoint.sh" ]
CMD dotnet NadekoBot.dll "$shard_id" "$total_shards"
