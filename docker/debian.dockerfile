ARG LUTE_VERSION
ARG BIN_IMAGE=ghcr.io/luau-lang/lute:bin-${LUTE_VERSION}

FROM ${BIN_IMAGE} AS bin

FROM debian:stable-slim

ARG LUTE_VERSION
ENV LUTE_VERSION=${LUTE_VERSION}

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=bin /lute /usr/local/bin/lute

COPY docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["docker-entrypoint.sh"]

CMD ["--help"]
