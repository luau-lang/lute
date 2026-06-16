---
order: 8
---

# Docker

Lute publishes official container images to the [GitHub Container Registry](https://github.com/luau-lang/lute/pkgs/container/lute) on every stable (non-nightly) release. They cover both `linux/amd64` and `linux/arm64`.

## Available images

| Image | Base | When to use it |
| --- | --- | --- |
| `ghcr.io/luau-lang/lute` | `debian:stable-slim` | The default. Includes a shell and common utilities, suitable for most use cases. |
| `ghcr.io/luau-lang/lute:distroless` | `gcr.io/distroless/cc-debian13` | Minimal runtime image. No shell or package manager. Smallest attack surface. |
| `ghcr.io/luau-lang/lute:bin` | `scratch` | Just the `lute` binary, intended for use as a build stage in your own Dockerfiles. |

## Tags

For a release of version `X.Y.Z`, the workflow publishes the following tags:

- Default (debian) variant: `latest`, `X`, `X.Y`, `X.Y.Z`, plus the same set prefixed with `debian-` (e.g. `debian`, `debian-X`, `debian-X.Y`, `debian-X.Y.Z`).
- Distroless variant: `distroless`, `distroless-X`, `distroless-X.Y`, `distroless-X.Y.Z`.
- Binary-only variant: `bin`, `bin-X`, `bin-X.Y`, `bin-X.Y.Z`.

Pin to `X.Y.Z` for reproducible builds, `X.Y` to receive patch updates, or `X` to receive minor and patch updates within a major version.

## Running Lute

Print the Lute CLI help (the default `CMD`):

```bash
docker run --rm ghcr.io/luau-lang/lute
```

Run a `script.luau` file from your current directory:

```bash
docker run --init --rm -it -v "$PWD:/app" -w /app ghcr.io/luau-lang/lute run script.luau
```

Open a shell inside the container (debian variant only):

```bash
docker run --rm -it ghcr.io/luau-lang/lute sh
```

The `--init` flag is recommended so signals like `Ctrl+C` are forwarded to `lute` correctly. `-v "$PWD:/app"` mounts the current directory into the container, and `-w /app` makes it the working directory.

## Using Lute in your own Dockerfile

You can extend the default image directly:

```dockerfile
FROM ghcr.io/luau-lang/lute:1

WORKDIR /app
COPY . .

CMD ["run", "server.luau"]
```

Or use the binary-only image to install Lute into any base image you want:

```dockerfile
FROM ubuntu:24.04

COPY --from=ghcr.io/luau-lang/lute:bin /lute /usr/local/bin/

CMD ["lute", "--help"]
```
