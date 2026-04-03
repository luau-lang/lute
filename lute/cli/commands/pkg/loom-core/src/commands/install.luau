local resolution = require("../resolver/resolution")
local projectManifest = require("../manifest/projectmanifest")
local pp = require("../../extern/pp")

local fsUtils = require("../utils/fsutils")
local luau = require("@std/luau")

local authenticationStore = require("../authentication/authenticationstore")
local git = require("../packagesource/git")
local process = require("@std/process")

local function executeLuauSource(source: string): any
	local bytecode = luau.compile(source)
	local func = luau.load(bytecode, "loom.config.luau", {})
	return func()
end

local function getGithubAuthenticationToken(): string?
	local githubToken = process.env.GITHUB_TOKEN
	if githubToken ~= nil then
		return githubToken
	end

	local store = authenticationStore.loadAuthenticationStore()
	local entry = store["github.com"]
	if entry ~= nil then
		return entry.token
	end

	return nil
end

local function install()
	local manifestPath = "loom.config.luau"
	local manifestContent = fsUtils.readfiletostring(manifestPath)
	local manifestTable = executeLuauSource(manifestContent)
	local manifest = projectManifest.fromTable(manifestTable)

	local projectResolution = resolution.fromManifest(manifest)

	local lockfile = resolution.toLockFile(projectResolution)
	fsUtils.writestringtofile("loom.lock.luau", "return " .. pp(lockfile))

	for _, pkg in projectResolution.packages do
		print(`package: {pkg.name}, Rev: {pkg.rev}, Source: {pkg.sourceKind} - {pkg.source}`)
		if pkg.sourceKind == "github" then
			local authToken = getGithubAuthenticationToken()
			local zipArchive = git:downloadFromGitHubArchive(pkg.source, authToken)
			git:installZipArchive(pkg.name, pkg.rev, zipArchive)
		end
	end
end

return install
