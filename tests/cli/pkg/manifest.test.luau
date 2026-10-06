local fs = require("@std/fs")
local manifest = require("@commands/pkg/loom-core/src/manifest")
local path = require("@std/path")
local system = require("@std/system")
local test = require("@std/test")

local workingDirectory = path.join(system.tmpdir(), "lute-pkg-manifest")
local manifestPath = path.join(workingDirectory, "loom.config.luau")

local function writeManifest(contents: string)
	fs.writeStringToFile(manifestPath, contents)
end

test.suite("PackageManifest", function(suite)
	suite:beforeEach(function()
		if fs.exists(workingDirectory) then
			fs.removeDirectory(workingDirectory, { recursive = true })
		end
		fs.createDirectory(workingDirectory)
	end)

	suite:case("parsesRegistryAndShorthandRegistryDependency", function(assert)
		writeManifest([[return {
	package = {
		name = "root",
		version = "0.0.0",
		dependencies = {
			citrus = "^1.0.0",
		},
	},
	registry = "https://registry.example.com",
}
]])

		local parsed = manifest.parseFile(path.format(manifestPath))
		local citrus = (parsed.package :: manifest.PackageManifest).dependencies.citrus
		local registryCitrus = citrus :: manifest.RegistryDependencySpec

		assert.eq(parsed.registry, "https://registry.example.com")
		assert.eq(registryCitrus.name, "citrus")
		assert.eq(registryCitrus.sourceKind, "registry")
		assert.eq(registryCitrus.source, "citrus")
		assert.eq(registryCitrus.version, "^1.0.0")
	end)

	suite:case("usesExplicitRegistrySourceAsThePackageName", function(assert)
		writeManifest([[return {
	package = {
		name = "root",
		version = "0.0.0",
		dependencies = {
			myCitrus = {
				sourceKind = "registry",
				source = "org/citrus",
				version = "^1.0.0",
			},
		},
	},
}
]])

		local parsed = manifest.parseFile(path.format(manifestPath))
		local citrus = (parsed.package :: manifest.PackageManifest).dependencies.myCitrus :: manifest.RegistryDependencySpec

		assert.eq(citrus.name, "org/citrus")
		assert.eq(citrus.source, "org/citrus")
	end)

	suite:case("usesExplicitPathAndGitNamesOrTheirAliases", function(assert)
		writeManifest([[return {
	package = {
		name = "root",
		version = "0.0.0",
		dependencies = {
			implicitPath = { sourceKind = "path", source = "./path" },
			explicitPath = { name = "path-member", sourceKind = "path", source = "./path" },
			implicitGit = { sourceKind = "github", source = "owner/repo", rev = "revision" },
			explicitGit = { name = "git-member", sourceKind = "github", source = "owner/repo", rev = "revision" },
		},
	},
}
]])

		local dependencies = (manifest.parseFile(path.format(manifestPath)).package :: manifest.PackageManifest).dependencies
		local implicitPath = dependencies.implicitPath :: manifest.PathDependencySpec
		local explicitPath = dependencies.explicitPath :: manifest.PathDependencySpec
		local implicitGit = dependencies.implicitGit :: manifest.GitHubDependencySpec
		local explicitGit = dependencies.explicitGit :: manifest.GitHubDependencySpec
		assert.eq(implicitPath.name, "implicitPath")
		assert.eq(explicitPath.name, "path-member")
		assert.eq(implicitGit.name, "implicitGit")
		assert.eq(explicitGit.name, "git-member")
	end)

	suite:case("rejectsExplicitNameForRegistryDependency", function(assert)
		writeManifest([[return {
	package = {
		name = "root",
		version = "0.0.0",
		dependencies = {
			myCitrus = {
				sourceKind = "registry",
				name = "citrus",
				source = "org/citrus",
				version = "^1.0.0",
			},
		},
	},
}
]])

		assert.throwsWith(
			"Registry dependency 'myCitrus' in dependencies does not support a 'name' field; use 'source' for the registry package name",
			function()
				manifest.parseFile(path.format(manifestPath))
			end
		)
	end)

	suite:case("rejectsNonStringRegistry", function(assert)
		writeManifest([[return {
	package = {
		name = "root",
		version = "0.0.0",
	},
	registry = 1,
}
]])

		assert.throwsWith("Expected 'registry' field to be a string URL", function()
			manifest.parseFile(path.format(manifestPath))
		end)
	end)
end)

test.suite("WorkspaceManifest", function(suite)
	suite:beforeEach(function()
		if fs.exists(workingDirectory) then
			fs.removeDirectory(workingDirectory, { recursive = true })
		end
		fs.createDirectory(workingDirectory)
	end)

	suite:case("parsesWorkspaceOnlyManifest", function(assert)
		writeManifest([[return {
	workspace = {
		version = "0.0.0",
		members = { "packages/*" },
		default_member = "app",
	},
	registry = "https://registry.example.com",
}
]])

		local parsed = manifest.parseFile(path.format(manifestPath))
		assert.eq(parsed.package, nil)
		assert.neq(parsed.workspace, nil)
		assert.eq((parsed.workspace :: manifest.WorkspaceManifest).members[1], "packages/*")
		assert.eq((parsed.workspace :: manifest.WorkspaceManifest).defaultMember, "app")
		assert.eq(parsed.registry, "https://registry.example.com")
	end)

	suite:case("parsesPackageAndWorkspaceManifest", function(assert)
		writeManifest([[return {
	package = { name = "root", version = "0.0.0" },
	workspace = { members = { "packages/*" } },
}
]])

		local parsed = manifest.parseFile(path.format(manifestPath))
		assert.eq((parsed.package :: manifest.PackageManifest).name, "root")
		assert.eq((parsed.workspace :: manifest.WorkspaceManifest).members[1], "packages/*")
	end)

	suite:case("rejectsManifestWithoutPackageOrWorkspace", function(assert)
		writeManifest("return {}")

		assert.throwsWith("Expected 'package' or 'workspace' field in manifest", function()
			manifest.parseFile(path.format(manifestPath))
		end)
	end)

	suite:case("rejectsWorkspaceWithoutMembers", function(assert)
		writeManifest("return { workspace = {} }")

		assert.throwsWith("Expected 'members' field in workspace manifest", function()
			manifest.parseFile(path.format(manifestPath))
		end)
	end)

	suite:case("rejectsNonStringWorkspaceMember", function(assert)
		writeManifest("return { workspace = { members = { 1 } } }")

		assert.throwsWith("Expected workspace member at index '1' to be a string", function()
			manifest.parseFile(path.format(manifestPath))
		end)
	end)

	suite:case("rejectsNonStringDefaultMember", function(assert)
		writeManifest("return { workspace = { members = {}, default_member = 1 } }")

		assert.throwsWith("Expected workspace default_member to be a string", function()
			manifest.parseFile(path.format(manifestPath))
		end)
	end)
end)
