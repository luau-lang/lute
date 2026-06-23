local fs = require("@std/fs")
local path = require("@std/path")
local system = require("@std/system")
local test = require("@std/test")

local resolution = require("@commands/pkg/loom-core/src/resolution")
local parser = require("@commands/pkg/loom-core/src/semver/parser")
local solver = require("@commands/pkg/loom-core/src/semver/solver")

local temporaryDirectory = system.tmpdir()
local workingDirectory = path.join(temporaryDirectory, "lute-pkg-registry")

local function writeConfig(dir: path.Path, name: string, deps: string, devDeps: string?)
	local sections = `\t\tdependencies = \{{deps}\n\t\t}`
	if devDeps then
		sections ..= `,\n\t\tdev_dependencies = \{{devDeps}\n\t\t}`
	end

	fs.writeStringToFile(
		path.join(dir, "loom.config.luau"),
		`return \{\n\tpackage = \{\n\t\tname = "{name}",\n\t\tversion = "0.0.0",\n{sections},\n\t},\n}\n`
	)
end

local function namedVersion(name: string, vstr: string, deps: { [string]: solver.Requirement }?): solver.PackageVersion
	local v = parser.parse(vstr)
	return table.freeze({
		name = name,
		version = v,
		versionString = parser.format(v),
		dependencies = table.freeze(deps or {}),
	})
end

local function req(name: string, constraintStr: string): solver.Requirement
	return table.freeze({
		name = name,
		constraint = parser.parseConstraint(constraintStr),
	})
end

test.suite("RegistryResolution", function(suite)
	suite:beforeEach(function()
		if fs.exists(workingDirectory) then
			fs.removeDirectory(workingDirectory, { recursive = true })
		end
		fs.createDirectory(workingDirectory)
	end)

	suite:case("resolvesHighestSatisfyingVersion", function(assert)
		writeConfig(
			workingDirectory,
			"root",
			[[

			citrus = {
				sourceKind = "registry",
				source = "citrus",
				version = "^1.0.0",
			},]]
		)

		local universe: solver.Universe = {
			citrus = {
				namedVersion("citrus", "1.3.0"),
				namedVersion("citrus", "1.2.0"),
				namedVersion("citrus", "1.0.0"),
				namedVersion("citrus", "2.0.0"),
			},
		}

		local lock = resolution.resolve(path.format(workingDirectory), universe)

		assert.neq(lock.dependencies.citrus, nil)
		assert.eq(lock.dependencies.citrus, "citrus@1.3.0")
		assert.neq(lock.packages["citrus@1.3.0"], nil)
	end)

	suite:case("lockfileEntryHasCorrectShape", function(assert)
		writeConfig(
			workingDirectory,
			"root",
			[[

			citrus = {
				sourceKind = "registry",
				source = "citrus",
				version = "^1.0.0",
			},]]
		)

		local universe: solver.Universe = {
			citrus = {
				namedVersion("citrus", "1.2.0"),
			},
		}

		local lock = resolution.resolve(path.format(workingDirectory), universe)

		local entry = lock.packages["citrus@1.2.0"]
		assert.neq(entry, nil)
		assert.eq(entry.name, "citrus")
		assert.eq(entry.rev, "1.2.0")
		assert.eq(entry.source, "citrus")
		assert.eq(entry.sourceKind, "registry")
		assert.eq(entry.installPath, "@pkg/citrus@1.2.0")
	end)

	suite:case("lockfileEntryPreservesSourceWhenDifferentFromName", function(assert)
		writeConfig(
			workingDirectory,
			"root",
			[[

			citrus = {
				sourceKind = "registry",
				source = "citrus/citrus",
				version = "^1.0.0",
			},]]
		)

		local universe: solver.Universe = {
			citrus = {
				namedVersion("citrus", "1.0.0"),
			},
		}

		local lock = resolution.resolve(path.format(workingDirectory), universe)

		assert.eq(lock.packages["citrus@1.0.0"].source, "citrus/citrus")
	end)

	suite:case("resolvesTransitiveDeps", function(assert)
		writeConfig(
			workingDirectory,
			"root",
			[[

			lemon = {
				sourceKind = "registry",
				source = "lemon",
				version = "^1.0.0",
			},]]
		)

		local universe: solver.Universe = {
			lemon = {
				namedVersion("lemon", "1.0.0", { citrus = req("citrus", "^2.0.0") }),
			},
			citrus = {
				namedVersion("citrus", "2.1.0"),
				namedVersion("citrus", "1.0.0"),
			},
		}

		local lock = resolution.resolve(path.format(workingDirectory), universe)

		assert.neq(lock.packages["lemon@1.0.0"], nil)
		assert.neq(lock.packages["citrus@2.1.0"], nil)
		assert.eq(lock.packages["lemon@1.0.0"].dependencies.citrus, "citrus@2.1.0")
	end)

	suite:case("resolvesDiamondDependency", function(assert)
		writeConfig(
			workingDirectory,
			"root",
			[[

			lemon = {
				sourceKind = "registry",
				source = "lemon",
				version = "^1.0.0",
			},
			lime = {
				sourceKind = "registry",
				source = "lime",
				version = "^0.5.0",
			},]]
		)

		local universe: solver.Universe = {
			lemon = {
				namedVersion("lemon", "1.3.0", { citrus = req("citrus", "^1.0.0") }),
			},
			lime = {
				namedVersion("lime", "0.5.1", { citrus = req("citrus", "^1.2.0") }),
			},
			citrus = {
				namedVersion("citrus", "1.5.0"),
				namedVersion("citrus", "1.2.0"),
				namedVersion("citrus", "1.0.0"),
			},
		}

		local lock = resolution.resolve(path.format(workingDirectory), universe)

		assert.neq(lock.packages["citrus@1.5.0"], nil)
		assert.eq(lock.packages["citrus@1.5.0"].sourceKind, "registry")
	end)

	suite:case("errorsWithNilUniverseWhenRegistryDepPresent", function(assert)
		writeConfig(
			workingDirectory,
			"root",
			[[

			citrus = {
				sourceKind = "registry",
				source = "citrus",
				version = "^1.0.0",
			},]]
		)

		assert.throwsWith("Registry dependencies require a universe to be provided", function()
			resolution.resolve(path.format(workingDirectory), nil)
		end)
	end)

	suite:case("errorsOnUnsatisfiableConstraint", function(assert)
		writeConfig(
			workingDirectory,
			"root",
			[[

			citrus = {
				sourceKind = "registry",
				source = "citrus",
				version = "^3.0.0",
			},]]
		)

		local universe: solver.Universe = {
			citrus = {
				namedVersion("citrus", "1.0.0"),
				namedVersion("citrus", "2.0.0"),
			},
		}

		assert.throwsWith("  >=3.0.0 <4.0.0  (required by root)", function()
			resolution.resolve(path.format(workingDirectory), universe)
		end)
	end)

	suite:case("mixedPathAndRegistryDeps", function(assert)
		local libDir = path.join(workingDirectory, "lib")
		fs.createDirectory(libDir)
		writeConfig(libDir, "lib", "")
		writeConfig(
			workingDirectory,
			"root",
			[[

			lib = {
				sourceKind = "path",
				source = "./lib",
			},
			citrus = {
				sourceKind = "registry",
				source = "citrus",
				version = "^1.0.0",
			},]]
		)

		local universe: solver.Universe = {
			citrus = {
				namedVersion("citrus", "1.1.0"),
			},
		}

		local lock = resolution.resolve(path.format(workingDirectory), universe)

		assert.neq(lock.packages["lib"], nil)
		assert.eq(lock.packages["lib"].sourceKind, "path")
		assert.neq(lock.packages["citrus@1.1.0"], nil)
		assert.eq(lock.packages["citrus@1.1.0"].sourceKind, "registry")
	end)

	suite:case("transitiveDepsFromPathPackageAreResolved", function(assert)
		local libDir = path.join(workingDirectory, "lib")
		fs.createDirectory(libDir)
		writeConfig(
			libDir,
			"lib",
			[[

			citrus = {
				sourceKind = "registry",
				source = "citrus",
				version = "^2.0.0",
			},]]
		)
		writeConfig(
			workingDirectory,
			"root",
			[[

			lib = {
				sourceKind = "path",
				source = "./lib",
			},]]
		)

		local universe: solver.Universe = {
			citrus = {
				namedVersion("citrus", "2.1.0"),
				namedVersion("citrus", "1.0.0"),
			},
		}

		local lock = resolution.resolve(path.format(workingDirectory), universe)

		assert.neq(lock.packages["lib"], nil)
		assert.eq(lock.packages["lib"].sourceKind, "path")
		assert.neq(lock.packages["citrus@2.1.0"], nil)
		assert.eq(lock.packages["lib"].dependencies.citrus, "citrus@2.1.0")
	end)

	suite:case("aliasCanDifferFromPackageName", function(assert)
		writeConfig(
			workingDirectory,
			"root",
			[[

			mylib = {
				sourceKind = "registry",
				name = "citrus",
				source = "citrus",
				version = "^1.0.0",
			},]]
		)

		local universe: solver.Universe = {
			citrus = {
				namedVersion("citrus", "1.2.0"),
			},
		}

		local lock = resolution.resolve(path.format(workingDirectory), universe)

		assert.eq(lock.dependencies.mylib, "citrus@1.2.0")
		assert.neq(lock.packages["citrus@1.2.0"], nil)
		assert.eq(lock.packages["citrus@1.2.0"].name, "citrus")
	end)

	suite:case("conflictMessageAttributesConstraintsToAliases", function(assert)
		writeConfig(
			workingDirectory,
			"root",
			[[

			lemon = {
				sourceKind = "registry",
				name = "citrus",
				source = "citrus",
				version = "^1.0.0",
			},
			lime = {
				sourceKind = "registry",
				name = "citrus",
				source = "citrus",
				version = "^2.0.0",
			},]]
		)

		local universe: solver.Universe = {
			citrus = {
				namedVersion("citrus", "1.0.0"),
				namedVersion("citrus", "2.0.0"),
			},
		}

		local ok = xpcall(resolution.resolve, function(msg)
			assert.strContains(msg, "required by root as lemon")
			assert.strContains(msg, "required by root as lime")
		end, path.format(workingDirectory), universe)
		assert.that(not ok)
	end)

	suite:case("allowsPathAndRegistryDepWithSameInternalName", function(assert)
		local citrusDir = path.join(workingDirectory, "citrus_local")
		fs.createDirectory(citrusDir)
		writeConfig(citrusDir, "citrus", "")
		writeConfig(
			workingDirectory,
			"root",
			[[

			citrus_local = {
				sourceKind = "path",
				name = "citrus",
				source = "./citrus_local",
			},
			citrus = {
				sourceKind = "registry",
				source = "citrus",
				version = "^1.0.0",
			},]]
		)

		local universe: solver.Universe = {
			citrus = {
				namedVersion("citrus", "1.0.0"),
			},
		}

		local lock = resolution.resolve(path.format(workingDirectory), universe)

		assert.neq(lock.packages["citrus"], nil)
		assert.eq(lock.packages["citrus"].sourceKind, "path")
		assert.neq(lock.packages["citrus@1.0.0"], nil)
		assert.eq(lock.packages["citrus@1.0.0"].sourceKind, "registry")
	end)

	suite:case("allowsDifferentSourcesForSameNameUnderDifferentAliases", function(assert)
		writeConfig(
			workingDirectory,
			"root",
			[[

			a = {
				sourceKind = "registry",
				name = "citrus",
				source = "org-one/citrus",
				version = "^1.0.0",
			},
			b = {
				sourceKind = "registry",
				name = "citrus",
				source = "org-two/citrus",
				version = "^1.0.0",
			},]]
		)

		local universe: solver.Universe = {
			citrus = {
				namedVersion("citrus", "1.0.0"),
			},
		}

		local lock = resolution.resolve(path.format(workingDirectory), universe)

		assert.eq(lock.dependencies.a, "citrus@1.0.0")
		assert.eq(lock.dependencies.b, "citrus@1.0.0")
	end)

	suite:case("writesLockfileToDisk", function(assert)
		writeConfig(
			workingDirectory,
			"root",
			[[

			citrus = {
				sourceKind = "registry",
				source = "citrus",
				version = "^1.0.0",
			},]]
		)

		local universe: solver.Universe = {
			citrus = {
				namedVersion("citrus", "1.0.0"),
			},
		}

		resolution.resolve(path.format(workingDirectory), universe)

		local lockfilePath = path.join(workingDirectory, "loom.lock.luau")
		assert.that(fs.exists(lockfilePath))

		local content = fs.readFileToString(lockfilePath)
		assert.strContains(content, '"registry"')
		assert.strContains(content, "citrus@1.0.0")
	end)
end)

test.suite("DevDependencies", function(suite)
	suite:beforeEach(function()
		if fs.exists(workingDirectory) then
			fs.removeDirectory(workingDirectory, { recursive = true })
		end
		fs.createDirectory(workingDirectory)
	end)

	suite:case("devDependenciesResolvedForRoot", function(assert)
		local devDir = path.join(workingDirectory, "testlib")
		fs.createDirectory(devDir)
		writeConfig(devDir, "testlib", "")
		writeConfig(
			workingDirectory,
			"root",
			"",
			[[

			testlib = {
				sourceKind = "path",
				source = "./testlib",
			},]]
		)

		local lock = resolution.resolve(path.format(workingDirectory), nil)

		assert.eq(lock.dependencies.testlib, "testlib")
		assert.eq(lock.packages["testlib"], {
			name = "testlib",
			sourceKind = "path",
			source = "./testlib",
			installPath = "testlib",
			dependencies = {},
		})
	end)

	suite:case("devDependenciesOfTransitivePathDepsExcluded", function(assert)
		local libDir = path.join(workingDirectory, "lib")
		fs.createDirectory(libDir)

		local libDevDir = path.join(libDir, "libtest")
		fs.createDirectory(libDevDir)
		writeConfig(libDevDir, "libtest", "")

		writeConfig(
			libDir,
			"lib",
			"",
			[[

			libtest = {
				sourceKind = "path",
				source = "./libtest",
			},]]
		)
		writeConfig(
			workingDirectory,
			"root",
			[[

			lib = {
				sourceKind = "path",
				source = "./lib",
			},]]
		)

		local lock = resolution.resolve(path.format(workingDirectory), nil)

		assert.eq(lock.dependencies.lib, "lib")
		assert.eq(lock.packages["lib"], {
			name = "lib",
			sourceKind = "path",
			source = "./lib",
			installPath = "lib",
			dependencies = {},
		})
		assert.eq(lock.packages["libtest"], nil)
		assert.eq(lock.dependencies.libtest, nil)
	end)

	suite:case("devDependenciesOfTransitiveRegistryDepsExcluded", function(assert)
		writeConfig(
			workingDirectory,
			"root",
			[[

			citrus = {
				sourceKind = "registry",
				source = "citrus",
				version = "^1.0.0",
			},]]
		)

		-- mocklib exists in the universe but is never required — verifies the solver
		-- only resolves what's actually reachable through prod dependency edges
		local universe: solver.Universe = {
			citrus = {
				namedVersion("citrus", "1.0.0"),
			},
			mocklib = {
				namedVersion("mocklib", "2.0.0"),
			},
		}

		local lock = resolution.resolve(path.format(workingDirectory), universe)

		assert.eq(lock.dependencies.citrus, "citrus@1.0.0")
		assert.eq(lock.packages["citrus@1.0.0"], {
			name = "citrus",
			rev = "1.0.0",
			source = "citrus",
			sourceKind = "registry",
			installPath = "@pkg/citrus@1.0.0",
			dependencies = {},
		})
		assert.eq(lock.packages["mocklib@2.0.0"], nil)
		assert.eq(lock.dependencies.mocklib, nil)
	end)

	suite:case("devAndProdShareTransitiveDep", function(assert)
		local sharedDir = path.join(workingDirectory, "shared")
		fs.createDirectory(sharedDir)
		writeConfig(sharedDir, "shared", "")

		local libDir = path.join(workingDirectory, "lib")
		fs.createDirectory(libDir)
		writeConfig(
			libDir,
			"lib",
			[[

			shared = {
				sourceKind = "path",
				source = "../shared",
			},]]
		)

		local testDir = path.join(workingDirectory, "testlib")
		fs.createDirectory(testDir)
		writeConfig(
			testDir,
			"testlib",
			[[

			shared = {
				sourceKind = "path",
				source = "../shared",
			},]]
		)

		writeConfig(
			workingDirectory,
			"root",
			[[

			lib = {
				sourceKind = "path",
				source = "./lib",
			},]],
			[[

			testlib = {
				sourceKind = "path",
				source = "./testlib",
			},]]
		)

		local lock = resolution.resolve(path.format(workingDirectory), nil)

		assert.eq(lock.dependencies.lib, "lib")
		assert.eq(lock.dependencies.testlib, "testlib")
		assert.eq(lock.packages["shared"], {
			name = "shared",
			sourceKind = "path",
			source = "shared",
			installPath = "shared",
			dependencies = {},
		})
		assert.eq(lock.packages["lib"].dependencies.shared, "shared")
		assert.eq(lock.packages["testlib"].dependencies.shared, "shared")
	end)

	suite:case("devRegistryDependencyResolved", function(assert)
		writeConfig(
			workingDirectory,
			"root",
			"",
			[[

			testing = {
				sourceKind = "registry",
				source = "testing",
				version = "^1.0.0",
			},]]
		)

		local universe: solver.Universe = {
			testing = {
				namedVersion("testing", "1.2.0"),
				namedVersion("testing", "1.0.0"),
			},
		}

		local lock = resolution.resolve(path.format(workingDirectory), universe)

		assert.eq(lock.dependencies.testing, "testing@1.2.0")
		assert.eq(lock.packages["testing@1.2.0"], {
			name = "testing",
			rev = "1.2.0",
			source = "testing",
			sourceKind = "registry",
			installPath = "@pkg/testing@1.2.0",
			dependencies = {},
		})
	end)

	suite:case("excludeDevSkipsDevDeps", function(assert)
		local devDir = path.join(workingDirectory, "testlib")
		fs.createDirectory(devDir)
		writeConfig(devDir, "testlib", "")
		writeConfig(
			workingDirectory,
			"root",
			"",
			[[

			testlib = {
				sourceKind = "path",
				source = "./testlib",
			},]]
		)

		local lock = resolution.resolve(path.format(workingDirectory), nil, { excludeDev = true })

		assert.eq(lock.dependencies.testlib, nil)
		assert.eq(lock.packages["testlib"], nil)
	end)

	suite:case("excludeDevKeepsProdDeps", function(assert)
		local libDir = path.join(workingDirectory, "lib")
		fs.createDirectory(libDir)
		writeConfig(libDir, "lib", "")

		local devDir = path.join(workingDirectory, "testlib")
		fs.createDirectory(devDir)
		writeConfig(devDir, "testlib", "")

		writeConfig(
			workingDirectory,
			"root",
			[[

			lib = {
				sourceKind = "path",
				source = "./lib",
			},]],
			[[

			testlib = {
				sourceKind = "path",
				source = "./testlib",
			},]]
		)

		local lock = resolution.resolve(path.format(workingDirectory), nil, { excludeDev = true })

		assert.eq(lock.dependencies.lib, "lib")
		assert.eq(lock.packages["lib"], {
			name = "lib",
			sourceKind = "path",
			source = "./lib",
			installPath = "lib",
			dependencies = {},
		})
		assert.eq(lock.dependencies.testlib, nil)
		assert.eq(lock.packages["testlib"], nil)
	end)

	suite:case("excludeDevSkipsRegistryDevDeps", function(assert)
		writeConfig(
			workingDirectory,
			"root",
			"",
			[[

			testing = {
				sourceKind = "registry",
				source = "testing",
				version = "^1.0.0",
			},]]
		)

		local universe: solver.Universe = {
			testing = {
				namedVersion("testing", "1.2.0"),
			},
		}

		local lock = resolution.resolve(path.format(workingDirectory), universe, { excludeDev = true })

		assert.eq(lock.dependencies.testing, nil)
		assert.eq(lock.packages["testing@1.2.0"], nil)
	end)

	suite:case("duplicateAliasAcrossSectionsErrors", function(assert)
		local libDir = path.join(workingDirectory, "lib")
		fs.createDirectory(libDir)
		writeConfig(libDir, "lib", "")

		writeConfig(
			workingDirectory,
			"root",
			[[

			lib = {
				sourceKind = "path",
				source = "./lib",
			},]],
			[[

			lib = {
				sourceKind = "path",
				source = "./lib",
			},]]
		)

		assert.throwsWith("Alias 'lib' appears in both dependencies and dev_dependencies", function()
			resolution.resolve(path.format(workingDirectory), nil)
		end)
	end)

	suite:case("lockfileVersionRemainsThree", function(assert)
		local devDir = path.join(workingDirectory, "testlib")
		fs.createDirectory(devDir)
		writeConfig(devDir, "testlib", "")
		writeConfig(
			workingDirectory,
			"root",
			"",
			[[

			testlib = {
				sourceKind = "path",
				source = "./testlib",
			},]]
		)

		resolution.resolve(path.format(workingDirectory), nil)

		local lockfilePath = path.join(workingDirectory, "loom.lock.luau")
		local content = fs.readFileToString(lockfilePath)
		assert.strContains(content, "version = 3")
	end)
end)
