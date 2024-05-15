FROM alpine:3.19.1@sha256:c5b1261d6d3e43071626931fc004f70149baeba2c8ec672bd4f27761f8e1ad6b as nadeko-source

WORKDIR /nadeko

# renovate: datasource=gitlab-tags depName=Kwoth/nadekobot
ARG NADEKO_VERSION=4.3.22

RUN apk add git curl && \
    git clone https://gitlab.com/Kwoth/nadekobot.git --branch=${NADEKO_VERSION} . && \
    mkdir /app && \
    curl -L https://yt-dl.org/downloads/latest/youtube-dl -o /app/youtube-dl

FROM mcr.microsoft.com/dotnet/sdk:6.0@sha256:43828fdf61c84cdaf488caf12d34fa35aa72edf46cc1c1100ac48f329cea8e98 AS build
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
FROM mcr.microsoft.com/dotnet/runtime:6.0@sha256:2fb01ba4963f7e6e81e4e5c271472be58886dc382ecbe1cc35f6e1aab136e308
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
