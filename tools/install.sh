#!/usr/bin/env sh
# Network installer for lute.
#
# Downloads the latest release build for this platform and hands off to
# `lute self install`, which copies the binary into ~/.lute/bin and wires up
# PATH.
#
# Usage:
#   curl --proto '=https' --tlsv1.2 -fsSL https://lute.sh/install.sh | sh
#   curl ... | sh -s -- --no-modify-path        # forward flags to self install
#
# Any arguments after `--` are forwarded verbatim to `lute self install`.

set -eu

REPO="luau-lang/lute"

os="$(uname -s)"
arch="$(uname -m)"

case "$os" in
	Darwin) os_name="macos" ;;
	Linux) os_name="linux" ;;
	*)
		echo "lute: unsupported operating system: $os" >&2
		exit 1
		;;
esac

case "$arch" in
	arm64 | aarch64) arch_name="aarch64" ;;
	x86_64 | amd64) arch_name="x86_64" ;;
	*)
		echo "lute: unsupported architecture: $arch" >&2
		exit 1
		;;
esac

asset="lute-${os_name}-${arch_name}.zip"
url="https://github.com/${REPO}/releases/latest/download/${asset}"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "lute: downloading $asset"
curl --proto '=https' --tlsv1.2 -fsSL "$url" -o "$tmp/lute.zip"

unzip -q "$tmp/lute.zip" -d "$tmp"

exe="$tmp/lute"
chmod +x "$exe"

echo "lute: running self install"
"$exe" self install "$@"
