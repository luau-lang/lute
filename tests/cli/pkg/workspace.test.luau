local fs = require("@std/fs")
local manifest = require("@commands/pkg/loom-core/src/manifest")
local path = require("@std/path")
local system = require("@std/system")
local test = require("@std/test")
local workspace = require("@commands/pkg/loom-core/src/workspace")

local workingDirectory = path.join(system.tmpdir(), "lute-pkg-workspace")

local function writeManifest(directory: path.Path, contents: string)
	fs.writeStringToFile(path.join(directory, "loom.config.luau"), contents)
end

local function writePackage(directory: path.Path, name: string, registry: string?)
	local registryField = if registry then `, registry = "{registry}"` else ""
	writeManifest(directory, `return \{ package = \{ name = "{name}", version = "0.0.0" \}{registryField} \}`)
end

local function parseRoot()
	local manifestPath = path.join(workingDirectory, "loom.config.luau")
	return manifest.parseFile(path.format(manifestPath))
end

test.suite("Workspace", function(suite)
	suite:beforeEach(function()
		if fs.exists(workingDirectory) then
			fs.removeDirectory(workingDirectory, { recursive = true })
		end
		fs.createDirectory(workingDirectory)
	end)

	suite:case("expandsMembersAndIncludesRootPackage", function(assert)
		local modules = path.join(workingDirectory, "modules")
		local first = path.join(modules, "first")
		local second = path.join(modules, "second")
		fs.createDirectory(modules)
		fs.createDirectory(first)
		fs.createDirectory(second)
		writePackage(first, "first")
		writePackage(second, "second")
		writeManifest(
			workingDirectory,
			[[return {
	package = { name = "root", version = "0.0.0" },
	workspace = { members = { "modules/*" }, default_member = "first" },
	registry = "https://registry.example.com",
}
]]
		)

		local resolved = workspace.resolve(path.format(workingDirectory), parseRoot())
		assert.eq(resolved.registry, "https://registry.example.com")
		assert.eq(resolved.members[1].name, "first")
		assert.eq(resolved.members[2].name, "second")
		assert.eq(resolved.members[3].name, "root")
	end)

	suite:case("rejectsDuplicateMemberPackageNames", function(assert)
		local modules = path.join(workingDirectory, "modules")
		local first = path.join(modules, "first")
		local second = path.join(modules, "second")
		fs.createDirectory(modules)
		fs.createDirectory(first)
		fs.createDirectory(second)
		writePackage(first, "duplicate")
		writePackage(second, "duplicate")
		writeManifest(workingDirectory, [[return { workspace = { members = { "modules/*" } } }]])

		assert.throwsWith("Duplicate workspace package name: 'duplicate'", function()
			workspace.resolve(path.format(workingDirectory), parseRoot())
		end)
	end)

	suite:case("rejectsMissingExplicitMemberDirectory", function(assert)
		writeManifest(workingDirectory, [[return { workspace = { members = { "missing" } } }]])

		assert.throwsWith("Workspace member directory not found: missing", function()
			workspace.resolve(path.format(workingDirectory), parseRoot())
		end)
	end)

	suite:case("rejectsUnknownDefaultMember", function(assert)
		local member = path.join(workingDirectory, "member")
		fs.createDirectory(member)
		writePackage(member, "member")
		writeManifest(
			workingDirectory,
			[[return { workspace = { members = { "member" }, default_member = "missing" } }]]
		)

		assert.throwsWith("Workspace default_member 'missing' is not a member", function()
			workspace.resolve(path.format(workingDirectory), parseRoot())
		end)
	end)

	suite:case("rejectsMemberRegistry", function(assert)
		local member = path.join(workingDirectory, "member")
		fs.createDirectory(member)
		writePackage(member, "member", "https://member-registry.example.com")
		writeManifest(workingDirectory, [[return { workspace = { members = { "member" } } }]])

		assert.throws(function()
			workspace.resolve(path.format(workingDirectory), parseRoot())
		end)
	end)

	suite:case("findsWorkspaceFromNestedMemberDirectory", function(assert)
		local member = path.join(workingDirectory, "member")
		local source = path.join(member, "src")
		fs.createDirectory(member)
		fs.createDirectory(source)
		writePackage(member, "member")
		writeManifest(workingDirectory, [[return { workspace = { members = { "member" } } }]])

		local rootDirectory, rootManifest = workspace.findRoot(path.format(source))
		assert.eq(rootDirectory, path.format(workingDirectory))
		assert.neq(rootManifest.workspace, nil)
	end)

	suite:case("errorsWhenNoManifestExists", function(assert)
		assert.throws(function()
			workspace.findRoot(path.format(workingDirectory))
		end)
	end)
end)
