# syntax=docker/dockerfile:1
#
# Home Assistant app "solvis2mqtt": a thin layer on the server image
# ghcr.io/lufi42/solvis2mqtt. run.sh builds base.xml from the app options
# (/data/options.json), takes the MQTT broker from the Supervisor and starts
# the server. Bump BUILD_FROM together with the version in config.yaml.
ARG BUILD_FROM=ghcr.io/lufi42/solvis2mqtt:1.0.0
FROM ${BUILD_FROM}

LABEL io.hass.type="addon" \
      org.opencontainers.image.title="solvis2mqtt (Home Assistant app)" \
      org.opencontainers.image.source="https://github.com/lufi42/hassio-addons" \
      org.opencontainers.image.licenses="MIT"

# The server image runs as uid 1000; the app runs as root like other apps, so that
# /data (mounted by the Supervisor) and /config are writable without extra setup.
USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends jq curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --chmod=755 rootfs/run.sh /run.sh

WORKDIR /data
ENTRYPOINT ["/run.sh"]
