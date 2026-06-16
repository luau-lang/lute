# Lute Docker Sources

Source Dockerfiles for the official Lute container images. The images are built and published to `ghcr.io/luau-lang/lute` by the `release` workflow on every stable (non-nightly) release.

See the [Docker guide](../docs/guide/docker.md) for the list of image variants, tags, and usage examples.

## Building locally

The Dockerfiles fetch the `lute` binary from the GitHub Releases page for the requested version, so any released version can be built locally:

```bash
docker buildx build \
    --build-arg LUTE_VERSION=1.0.0 \
    -f docker/bin.dockerfile \
    -t lute:bin docker

docker buildx build \
    --build-arg LUTE_VERSION=1.0.0 \
    --build-arg BIN_IMAGE=lute:bin \
    -f docker/debian.dockerfile \
    -t lute:debian docker
```
