FROM alpine:3.22.1@sha256:4bcff63911fcb4448bd4fdacec207030997caf25e9bea4045fa6c8c44de311d1 as nadeko-source

WORKDIR /nadeko

# renovate: datasource=gitlab-tags depName=Kwoth/nadekobot
ARG NADEKO_VERSION=5.1.4

RUN apk add git curl && \
    git clone https://gitlab.com/Kwoth/nadekobot.git --branch=${NADEKO_VERSION} .

# COPY add_nuget_audit.sh /nadeko/

# RUN chmod +x add_nuget_audit.sh && \
#     ./add_nuget_audit.sh && \
#     rm add_nuget_audit.sh

# Build NadekoBot
FROM mcr.microsoft.com/dotnet/sdk:9.0@sha256:670ef9e8eca44c8baa0bd1c229ccde9537064260ef14d54738b7a87916609312 AS build
WORKDIR /source

# Copy the .csproj files for each project
COPY --from=nadeko-source /nadeko/src/Nadeko.Medusa/*.csproj src/Nadeko.Medusa/
COPY --from=nadeko-source /nadeko/src/NadekoBot/*.csproj src/NadekoBot/
COPY --from=nadeko-source /nadeko/src/NadekoBot.Coordinator/*.csproj src/NadekoBot.Coordinator/
COPY --from=nadeko-source /nadeko/src/NadekoBot.Generators/*.csproj src/NadekoBot.Generators/
COPY --from=nadeko-source /nadeko/src/NadekoBot.Voice/*.csproj src/NadekoBot.Voice/
COPY --from=nadeko-source /nadeko/NuGet.Config ./

# Restore the dependencies for the NadekoBot project
RUN dotnet restore src/NadekoBot/

# Copy the rest of the source code
COPY --from=nadeko-source /nadeko .

# Set the working directory to the NadekoBot project
WORKDIR /source/src/NadekoBot

# Build and publish the NadekoBot project, then clean up unnecessary files
RUN set -xe; \
    dotnet --version; \
    dotnet publish -c Release -o /app --no-restore; \
    mv /app/data /app/data_init; \
    rm -Rf libopus* libsodium* opus.* runtimes/win* runtimes/osx* runtimes/linux-arm* runtimes/linux-mips*; \
    find /app -type f -exec chmod -x {} \; ;\
    chmod +x /app/NadekoBot

# Final Image
FROM mcr.microsoft.com/dotnet/runtime:9.0@sha256:f90174159add063f40041160baf4ead693302a285c12fa74e60154f1d7acbc16
WORKDIR /app

# Create a new user, install dependencies, and set up sudoers file
RUN set -xe; \
    useradd -m nadeko; \
    apt-get update; \
    apt-get install -y --no-install-recommends libsqlite3-0 curl ffmpeg sudo python3; \
    echo 'Defaults>nadeko env_keep+="ASPNETCORE_* DOTNET_* NadekoBot_* shard_id total_shards TZ"' > /etc/sudoers.d/nadeko; \
    curl -Lo /usr/local/bin/yt-dlp https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp; \
    chmod a+rx /usr/local/bin/yt-dlp; \
    apt-get autoremove -y; \
    apt-get autoclean -y

COPY --from=build /app ./
COPY --from=nadeko-source /nadeko/docker-entrypoint.sh /usr/local/sbin

# Set environment variables
ENV shard_id=0
ENV total_shards=1
ENV NadekoBot__creds=/app/data/creds.yml

# Define the data directory as a volume
VOLUME [ "/app/data" ]

# Set the entrypoint and default command
ENTRYPOINT [ "/usr/local/sbin/docker-entrypoint.sh" ]
CMD dotnet NadekoBot.dll "$shard_id" "$total_shards"
