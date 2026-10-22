local fs = require("@std/fs")
local manifest = require("@commands/pkg/loom-core/src/manifest")
local path = require("@std/path")
local publishManifest = require("@commands/pkg/loom-core/src/publish")
local store = require("@commands/pkg/loom-core/src/store")
local system = require("@std/system")
local test = require("@std/test")

local workingDirectory = path.join(system.tmpdir(), "lute-pkg-publish-manifest")
local githubSource = "https://github.com/lute-pkg-tests/publish-fixture"
local githubRevision = "publish-test-revision"
local githubFixtureDirectory = store.getPackagePath(store.getGitHubCheckoutKey(githubSource, githubRevision))

local function writeManifest(directory: path.Path, contents: string)
	fs.writeStringToFile(path.join(directory, "loom.config.luau"), contents)
end

local function parseGeneratedManifest(contents: string): manifest.ProjectManifest
	local generatedPath = path.join(workingDirectory, "generated.luau")
	fs.writeStringToFile(generatedPath, contents)
	return manifest.parseFile(path.format(generatedPath))
end

local function writePackageManifest(directory: path.Path, name: string)
	fs.createDirectory(directory, { makeParents = true })
	writeManifest(
		directory,
		string.format(
			[[return {
	package = {
		name = %q,
		version = "1.0.0",
	},
}
]],
			name
		)
	)
end

test.suite("Publish", function(suite)
	suite:beforeEach(function()
		if fs.exists(workingDirectory) then
			fs.removeDirectory(workingDirectory, { recursive = true })
		end
		fs.createDirectory(workingDirectory)
	end)

	suite:afterEach(function()
		if fs.exists(githubFixtureDirectory) then
			fs.removeDirectory(githubFixtureDirectory, { recursive = true })
		end
	end)

	suite:case("flattensProductionAndDevelopmentDependencies", function(assert)
		writeManifest(
			workingDirectory,
			[[local alias = { sourceKind = "registry", source = "vendor/registry", version = "^1.0.0" }

return {
	package = {
		name = "publisher",
		version = "1.2.3",
		content_root = "src",
		files = { "**/*.luau", "!**/*.spec.luau" },
		dependencies = {
			registryAlias = alias,
			pathAlias = { sourceKind = "path", source = "./path", version = "^2.0.0" },
			gitAlias = { sourceKind = "github", source = "https://github.com/lute-pkg-tests/publish-fixture", rev = "publish-test-revision", target = "package", version = "~3.1.0" },
		},
		dev_dependencies = {
			devPath = { sourceKind = "path", source = "./dev-path", version = "^4.0.0" },
		},
	},
	overrides = {
		registryAlias = { sourceKind = "registry", source = "vendor/override", version = "^4.0.0" },
	},
	registry = "https://registry.example.com",
}
]]
		)
		writePackageManifest(path.join(workingDirectory, "path"), "vendor/path")
		writePackageManifest(path.join(workingDirectory, "dev-path"), "vendor/dev-path")
		writePackageManifest(path.join(path.parse(githubFixtureDirectory), "package"), "vendor/git")

		local sourceManifest = manifest.parseFile(path.format(path.join(workingDirectory, "loom.config.luau")))
		local flattened =
			publishManifest.flattenPackage(sourceManifest.package :: manifest.PackageManifest, sourceManifest.registry)
		local generated = parseGeneratedManifest(flattened)
		local package = generated.package :: manifest.PackageManifest

		assert.eq(package.name, "publisher")
		assert.eq(package.version, "1.2.3")
		assert.eq(package.contentRoot, "src")
		assert.eq(package.files, { "**/*.luau", "!**/*.spec.luau" })
		assert.eq(package.dependencies.registryAlias.sourceKind, "registry")
		assert.eq(package.dependencies.registryAlias.source, "vendor/registry")
		assert.eq(package.dependencies.pathAlias.sourceKind, "registry")
		assert.eq(package.dependencies.pathAlias.source, "vendor/path")
		assert.eq(package.dependencies.pathAlias.version, "^2.0.0")
		assert.eq(package.dependencies.gitAlias.sourceKind, "registry")
		assert.eq(package.dependencies.gitAlias.source, "vendor/git")
		assert.eq(package.dependencies.gitAlias.version, "~3.1.0")
		assert.eq(package.devDependencies.devPath.sourceKind, "registry")
		assert.eq(package.devDependencies.devPath.source, "vendor/dev-path")
		assert.eq(package.devDependencies.devPath.version, "^4.0.0")
		assert.eq(generated.registry, "https://registry.example.com")
		assert.eq(next(generated.overrides), nil)
		local gitAliasIndex = string.find(flattened, "gitAlias", 1, true) :: number
		local pathAliasIndex = string.find(flattened, "pathAlias", 1, true) :: number
		local registryAliasIndex = string.find(flattened, "registryAlias", 1, true) :: number
		assert.that(gitAliasIndex < pathAliasIndex)
		assert.that(pathAliasIndex < registryAliasIndex)
	end)

	suite:case("quotesKeywordDependencyAliases", function(assert)
		writeManifest(
			workingDirectory,
			[[return {
	package = {
		name = "publisher",
		version = "1.2.3",
		dependencies = {
			["end"] = "^1.0.0",
		},
	},
}
]]
		)

		local sourceManifest = manifest.parseFile(path.format(path.join(workingDirectory, "loom.config.luau")))
		local flattened = publishManifest.flattenPackage(sourceManifest.package :: manifest.PackageManifest)
		assert.strContains(flattened, '["end"] = {')

		local generated = parseGeneratedManifest(flattened)
		local package = generated.package :: manifest.PackageManifest
		assert.eq(package.dependencies["end"].source, "end")
	end)

	suite:case("rejectsProductionSourceDependencyWithoutAPublishVersion", function(assert)
		writeManifest(
			workingDirectory,
			[[return {
	package = {
		name = "publisher",
		version = "1.2.3",
		dependencies = {
			localDependency = { sourceKind = "path", source = "../local" },
		},
	},
}
]]
		)

		local sourceManifest = manifest.parseFile(path.format(path.join(workingDirectory, "loom.config.luau")))
		assert.throwsWith("Cannot publish dependency 'localDependency': path dependencies require a version", function()
			publishManifest.flattenPackage(sourceManifest.package :: manifest.PackageManifest)
		end)
	end)

	suite:case("dropsDevelopmentSourceDependencyWithoutAPublishVersion", function(assert)
		writeManifest(
			workingDirectory,
			[[return {
	package = {
		name = "publisher",
		version = "1.2.3",
		dev_dependencies = {
			localDependency = { sourceKind = "path", source = "../local" },
		},
	},
}
]]
		)

		local sourceManifest = manifest.parseFile(path.format(path.join(workingDirectory, "loom.config.luau")))
		local flattened = publishManifest.flattenPackage(sourceManifest.package :: manifest.PackageManifest)
		local generated = parseGeneratedManifest(flattened)
		assert.eq(next(generated.package.devDependencies), nil)
	end)

	suite:case("rejectsInvalidPublishedPackageVersion", function(assert)
		writeManifest(
			workingDirectory,
			[[return {
	package = {
		name = "publisher",
		version = "^1.2.3",
		dependencies = {
			registryDependency = "not-a-version",
		},
	},
}
]]
		)

		local sourceManifest = manifest.parseFile(path.format(path.join(workingDirectory, "loom.config.luau")))
		assert.throwsWith("Invalid package version: '^1.2.3'", function()
			publishManifest.flattenPackage(sourceManifest.package :: manifest.PackageManifest)
		end)
	end)

	suite:case("rejectsVirtualPackages", function(assert)
		writeManifest(
			workingDirectory,
			[[return {
	package = {
		dependencies = {
			member = { sourceKind = "path", source = "./member" },
		},
	},
}
]]
		)

		local sourceManifest = manifest.parseFile(path.format(path.join(workingDirectory, "loom.config.luau")))
		assert.throwsWith("Cannot publish a virtual package: package name and version are required", function()
			publishManifest.flattenPackage(sourceManifest.package)
		end)
	end)

	suite:case("rejectsInvalidPublishedDependencyConstraint", function(assert)
		writeManifest(
			workingDirectory,
			[[return {
	package = {
		name = "publisher",
		version = "1.2.3",
		dependencies = {
			registryDependency = "not-a-version",
		},
	},
}
]]
		)

		local sourceManifest = manifest.parseFile(path.format(path.join(workingDirectory, "loom.config.luau")))
		assert.throwsWith("Invalid dependency version constraint: 'not-a-version'", function()
			publishManifest.flattenPackage(sourceManifest.package :: manifest.PackageManifest)
		end)
	end)
end)
