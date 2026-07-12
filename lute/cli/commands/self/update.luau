local cli = require("@batteries/cli")
local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")

local paths = require("./paths")
local release = require("./release")

local HELP_STRING = [[
Update the host lute binary to the latest release.

OPTIONS:
  --version <version> Install a specific release (e.g. 1.0.1)
  -h, --help         Show this help message
]]

return function(...: string)
	local args = cli.parser()
	args:add("help", "flag", { help = "Show this help message", aliases = { "h" } })
	args:add("version", "option", { help = "Install a specific release tag instead of the latest" })
	args:parse({ ... })

	if args:has("help") then
		print("Usage: lute self update [options]\n")
		print(HELP_STRING)
		return
	end

	local destination = paths.exePath()
	local source = path.format(path.normalize(process.execPath()))

	if not fs.exists(destination) then
		error("No host lute found. Run `lute self install` first.")
	end

	if source ~= destination then
		print(`note: updating host lute at {destination}`)
		print(`      (currently running {source})`)
	elseif system.win32 then
		error("Windows cannot replace a running executable. Run this command from another copy of lute.")
	end

	local requested = args:get("version")

	local current: string? = nil
	local ok, result = pcall(process.run, { destination, "--version" }, nil)
	if ok and result.ok then
		current = release.normalizeTag(result.stdout)
	else
		print(`warning: could not read version from {destination}; proceeding with update`)
	end

	if requested == nil and current ~= nil and string.find(current, "-nightly.", 1, true) ~= nil then
		error("Automatic updates are not supported for nightly releases. Use --version to select a nightly release.")
	end

	local tag = if requested ~= nil then release.normalizeTag(requested) else release.queryLatestTag()
	if current == tag then
		print(`lute is up to date ({tag})`)
		return
	end

	print(`Updating lute: {current or "(unknown)"} -> {tag}`)
	release.downloadBinary(tag, destination)
	print(`Updated lute to {tag} at {destination}`)

	local setup = process.run({ destination, "setup" }, { stdio = "inherit" })
	if not setup.ok then
		print("warning: `lute setup` failed; run it manually to update type definitions")
	end
end
