FROM alpine:3.17.3@sha256:124c7d2707904eea7431fffe91522a01e5a861a624ee31d03372cc1d138a3126 as nadeko-source

WORKDIR /nadeko

# renovate: datasource=gitlab-tags depName=Kwoth/nadekobot
ARG NADEKO_VERSION=4.3.14

RUN apk add git curl && \
    git clone https://gitlab.com/Kwoth/nadekobot.git --branch=${NADEKO_VERSION} . && \
    mkdir /app && \
    curl -L https://yt-dl.org/downloads/latest/youtube-dl -o /app/youtube-dl

FROM mcr.microsoft.com/dotnet/sdk:6.0@sha256:f6f276c7fb4cd310d784f9568bd09f7a336539bcbb48dcf63ed52dd1240bc18e AS build
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
FROM mcr.microsoft.com/dotnet/runtime:6.0@sha256:ee26deabb180aba76bc0ce803782b66660df9d08f3ca6d81fd38b8d7fcde1b99
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
