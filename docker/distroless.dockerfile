ARG LUTE_VERSION
ARG BIN_IMAGE=ghcr.io/luau-lang/lute:bin-${LUTE_VERSION}

FROM ${BIN_IMAGE} AS bin

FROM gcr.io/distroless/cc-debian13

ARG LUTE_VERSION
ENV LUTE_VERSION=${LUTE_VERSION}

COPY --from=bin /lute /usr/local/bin/lute

ENTRYPOINT ["lute"]

CMD ["--help"]
