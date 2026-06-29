#!/usr/bin/env pwsh
# Network installer for lute (Windows).
#
# Downloads the latest release build for this platform and hands off to
# `lute.exe self install`, which copies the binary into ~/.lute/bin and
# wires up PATH.
#
# Usage:
#   irm https://lute.sh/install.ps1 | iex
#   powershell -c "irm https://lute.sh/install.ps1 | iex"

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$repo = "luau-lang/lute"
$asset = "lute-windows-x86_64.zip"
$url = "https://github.com/${repo}/releases/latest/download/${asset}"

$tmp = New-Item -ItemType Directory -Path (Join-Path $env:TEMP "lute-install-$(Get-Random)")

try {
	Write-Host "lute: downloading $asset"
	$headers = @{}
	if ($env:GITHUB_TOKEN) {
		$headers["Authorization"] = "Bearer $env:GITHUB_TOKEN"
	}
	Invoke-WebRequest -Uri $url -OutFile (Join-Path $tmp.FullName "lute.zip") -Headers $headers

	Write-Host "lute: extracting"
	Expand-Archive -Path (Join-Path $tmp.FullName "lute.zip") -DestinationPath $tmp.FullName -Force

	$exe = Join-Path $tmp.FullName "lute.exe"
	if (-not (Test-Path $exe)) {
		Write-Error "lute: lute.exe not found in archive"
		exit 1
	}

	Write-Host "lute: running self install"
	& $exe self install @args
}
finally {
	Remove-Item -Recurse -Force $tmp.FullName -ErrorAction SilentlyContinue
}
