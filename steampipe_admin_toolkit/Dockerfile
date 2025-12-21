FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl unzip tini \
 && rm -rf /var/lib/apt/lists/*

# Install Steampipe v1.x (dashboard removed; use Powerpipe)
ENV STEAMPIPE_VERSION=v1.1.4
RUN curl -fsSL -o /tmp/steampipe.tgz "https://github.com/turbot/steampipe/releases/download/${STEAMPIPE_VERSION}/steampipe_linux_amd64.tar.gz" \
 && tar -xzf /tmp/steampipe.tgz -C /usr/local/bin steampipe \
 && rm -f /tmp/steampipe.tgz

# Install Powerpipe CLI
ENV POWERPIPE_VERSION=v1.4.2
RUN curl -fsSL -o /tmp/powerpipe.tgz "https://github.com/turbot/powerpipe/releases/download/${POWERPIPE_VERSION}/powerpipe.linux.amd64.tar.gz" \
 && tar -xzf /tmp/powerpipe.tgz -C /usr/local/bin powerpipe \
 && rm -f /tmp/powerpipe.tgz

# Create unprivileged user
RUN useradd -m -u 10001 steampipe

WORKDIR /home/steampipe
ENV HOME=/home/steampipe

EXPOSE 8080 9193 9033
ENTRYPOINT ["/usr/bin/tini","--"]
CMD ["/entrypoint.sh"]
