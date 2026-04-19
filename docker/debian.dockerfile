ARG LUTE_VERSION
ARG BIN_IMAGE=ghcr.io/luau-lang/lute:bin-${LUTE_VERSION}

FROM ${BIN_IMAGE} AS bin

FROM debian:stable-slim

ARG LUTE_VERSION
ENV LUTE_VERSION=${LUTE_VERSION}

COPY --from=bin /lute /usr/local/bin/lute

COPY docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["docker-entrypoint.sh"]

CMD ["--help"]
