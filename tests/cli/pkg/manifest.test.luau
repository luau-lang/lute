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
		local citrus = parsed.package.dependencies.citrus
		local registryCitrus = citrus :: manifest.RegistryDependencySpec

		assert.eq(parsed.registry, "https://registry.example.com")
		assert.eq(registryCitrus.name, "citrus")
		assert.eq(registryCitrus.sourceKind, "registry")
		assert.eq(registryCitrus.source, "citrus")
		assert.eq(registryCitrus.version, "^1.0.0")
	end)

	suite:case("normalizesPackageContentRoot", function(assert)
		writeManifest([[return {
	package = {
		name = "root",
		version = "0.0.0",
		content_root = "./src/../src",
	},
}
]])

		local package = manifest.parseFile(path.format(manifestPath)).package
		assert.eq(package.contentRoot, "src")
	end)

	suite:case("parsesPackageFilesPatterns", function(assert)
		writeManifest([[return {
	package = {
		name = "root",
		version = "0.0.0",
		files = { "*.luau", "!**/*.spec.luau", "!**/__tests__/" },
	},
}
]])

		local package = manifest.parseFile(path.format(manifestPath)).package
		assert.eq(package.files, { "*.luau", "!**/*.spec.luau", "!**/__tests__/" })
	end)

	suite:case("rejectsNonArrayPackageFiles", function(assert)
		writeManifest([[return {
	package = {
		name = "root",
		version = "0.0.0",
		files = "*.luau",
	},
}
]])

		assert.throwsWith("Expected 'files' field in package manifest to be an array of strings", function()
			manifest.parseFile(path.format(manifestPath))
		end)
	end)

	suite:case("rejectsNonStringPackageFilesPattern", function(assert)
		writeManifest([[return {
	package = {
		name = "root",
		version = "0.0.0",
		files = { "*.luau", 1 },
	},
}
]])

		assert.throwsWith("Expected 'files' field in package manifest to be an array of strings", function()
			manifest.parseFile(path.format(manifestPath))
		end)
	end)

	suite:case("rejectsUnsafePackageContentRoot", function(assert)
		writeManifest([[return {
	package = {
		name = "root",
		version = "0.0.0",
		content_root = "../src",
	},
}
]])

		assert.throwsWith("'content_root' must stay inside the package directory", function()
			manifest.parseFile(path.format(manifestPath))
		end)
	end)

	suite:case("rejectsWindowsPathsInPackageContentRoot", function(assert)
		if not system.win32 then
			return
		end

		writeManifest([[return {
	package = {
		name = "root",
		version = "0.0.0",
		content_root = "..\\private",
	},
}
]])

		assert.throwsWith("'content_root' must stay inside the package directory", function()
			manifest.parseFile(path.format(manifestPath))
		end)

		writeManifest([[return {
	package = {
		name = "root",
		version = "0.0.0",
		content_root = "C:/private",
	},
}
]])

		assert.throwsWith("'content_root' must be relative to the package directory", function()
			manifest.parseFile(path.format(manifestPath))
		end)
	end)

	suite:case("rejectsAnEmptyPackageName", function(assert)
		writeManifest([[return {
	package = {
		name = "",
		version = "0.0.0",
	},
}
]])

		assert.throwsWith("Expected 'name' field in package manifest to be a non-empty string", function()
			manifest.parseFile(path.format(manifestPath))
		end)
	end)

	suite:case("rejectsAnEmptyPackageVersion", function(assert)
		writeManifest([[return {
	package = {
		name = "root",
		version = "",
	},
}
]])

		assert.throwsWith("Expected 'version' field in package manifest to be a non-empty string", function()
			manifest.parseFile(path.format(manifestPath))
		end)
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
		local citrus = parsed.package.dependencies.myCitrus

		assert.eq(citrus.name, "org/citrus")
		assert.eq(citrus.source, "org/citrus")
	end)

	suite:case("preservesOptionalPublishVersionsForSourceDependencies", function(assert)
		writeManifest([[return {
	package = {
		name = "root",
		version = "0.0.0",
		dependencies = {
			pathDependency = { sourceKind = "path", source = "./path", version = "^1.2.3" },
			gitDependency = { sourceKind = "github", source = "owner/repo", rev = "revision", version = ">=2.0.0 <3.0.0" },
		},
	},
}
]])

		local dependencies = (manifest.parseFile(path.format(manifestPath)).package :: manifest.PackageManifest).dependencies
		assert.eq((dependencies.pathDependency :: manifest.PathDependencySpec).version, "^1.2.3")
		assert.eq((dependencies.gitDependency :: manifest.GitHubDependencySpec).version, ">=2.0.0 <3.0.0")
	end)

	suite:case("rejectsNonStringPublishVersionForSourceDependencies", function(assert)
		writeManifest([[return { package = { name = "root", version = "0.0.0", dependencies = {
	pathDependency = { sourceKind = "path", source = "./path", version = 1 },
} } }]])

		assert.throwsWith(
			"Optional 'version' field in dependency spec for 'pathDependency' in dependencies expected to be a string",
			function()
				manifest.parseFile(path.format(manifestPath))
			end
		)
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

	suite:case("allowsAnIdentityLessManifest", function(assert)
		writeManifest([[return {
	package = {
		dependencies = {
			apple = {
				sourceKind = "github",
				source = "https://github.com/example/fruits",
				rev = "v1.0.0",
				target = "./modules/../package",
			},
		},
	},
}]])

		local parsed = manifest.parseFile(path.format(manifestPath))
		local apple = parsed.package.dependencies.apple :: manifest.GitHubDependencySpec
		assert.eq(parsed.package.name, nil)
		assert.eq(parsed.package.version, nil)
		assert.eq(apple.target, "package")
	end)

	suite:case("rejectsGitHubTargetOutsideTheRepository", function(assert)
		writeManifest([[return {
	package = {
		name = "root",
		version = "1.0.0",
		dependencies = {
			apple = {
				sourceKind = "github",
				source = "https://github.com/example/fruits",
				rev = "v1.0.0",
				target = "../apple",
			},
		},
	},
}]])

		assert.throwsWith(
			"'target' for github dependency 'apple' in dependencies must stay inside the repository",
			function()
				manifest.parseFile(path.format(manifestPath))
			end
		)
	end)

	suite:case("rejectsTargetForPathDependencies", function(assert)
		writeManifest([[return {
	package = {
		name = "root",
		version = "1.0.0",
		dependencies = {
			apple = {
				sourceKind = "path",
				source = "./modules/apple",
				target = "package",
			},
		},
	},
}]])

		assert.throwsWith(
			"Path dependency 'apple' in dependencies does not support a 'target' field; point 'source' directly at the package",
			function()
				manifest.parseFile(path.format(manifestPath))
			end
		)
	end)

	suite:case("requiresDependencyManifestsToHaveBothNameAndVersion", function(assert)
		writeManifest([[return {
	package = {
		name = "apple",
	},
}]])

		assert.throwsWith(
			"Package manifest must specify both 'name' and 'version', or neither for a virtual package",
			function()
				manifest.parseFile(path.format(manifestPath))
			end
		)
	end)
end)
