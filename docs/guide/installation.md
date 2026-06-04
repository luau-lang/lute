---
order: 2
---
# Installation

## Stable Releases

Lute has stable releases versioned according to [semantic versioning](https://semver.org/). You can find and download the latest stable release on the 
[releases page](https://github.com/luau-lang/lute/releases). They can also be installed with toolchain managers like [Rokit](https://github.com/rojo-rbx/rokit)
and [Foreman](https://github.com/Roblox/foreman).

## Install with Rokit

You can use [Rokit](https://github.com/rojo-rbx/rokit) to manage your Lute installation. If you have Rokit installed, simply run the following command in your project to install the latest stable version of Lute:

```bash
rokit add luau-lang/lute@1.0.0
```

## Install with Foreman

You can also use [Foreman](https://github.com/Roblox/foreman) to manage your Lute installation. If you have Foreman installed, you must first create a `foreman.toml` file in your project with the following content:

```toml
[tools]
lute = { github = "luau-lang/lute", version = "1.0.0" }
```

After creating the `foreman.toml` file, run the following command to install the latest stable version of Lute:
```bash
foreman install
```

## Docker

Official container images are published to the GitHub Container Registry on every stable release. The default image is based on `debian:stable-slim`:

```bash
docker run --rm -it -v "$PWD:/app" -w /app ghcr.io/luau-lang/lute run script.luau
```

See the [Docker guide](./docker) for the full list of image variants and tags.

## Nightly Builds

Unstable versions of Lute are available as a nightly build. You can find and download the latest build on [releases page](https://github.com/luau-lang/lute/releases).
They can be installed according to the instructions above with either Rokit or Foreman by specifying the desired version as `0.1.0-nightly.[date]` (e.g. `0.1.0-nightly.2024-06-01`).
