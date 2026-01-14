FROM alpine:3.23.2@sha256:865b95f46d98cf867a156fe4a135ad3fe50d2056aa3f25ed31662dff6da4eb62 as nadeko-source

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
FROM mcr.microsoft.com/dotnet/sdk:10.0@sha256:25d14b400b75fa4e89d5bd4487a92a604a4e409ab65becb91821e7dc4ac7f81f AS build
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
FROM mcr.microsoft.com/dotnet/runtime:10.0@sha256:d90a4ab2021c4be88de0c7575961baca2ec2e4de0b0d79441782c17cdbe2d0a4
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
