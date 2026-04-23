ARG LUTE_VERSION

FROM buildpack-deps:curl AS download

RUN apt-get update && apt-get install -y --no-install-recommends unzip \
    && rm -rf /var/lib/apt/lists/*

ARG LUTE_VERSION
ARG TARGETARCH

RUN ARCH=$(echo "$TARGETARCH" | sed -e 's/arm64/aarch64/' -e 's/amd64/x86_64/') \
    && curl -fsSL "https://github.com/luau-lang/lute/releases/download/v${LUTE_VERSION}/lute-linux-${ARCH}.zip" --output lute.zip \
    && unzip lute.zip \
    && chmod +x lute

FROM scratch

ARG LUTE_VERSION
ENV LUTE_VERSION=${LUTE_VERSION}

COPY --from=download /lute /lute
