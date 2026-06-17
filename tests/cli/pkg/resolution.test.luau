local fs = require("@std/fs")
local path = require("@std/path")
local system = require("@std/system")
local test = require("@std/test")

local lockfile = require("@commands/pkg/loom-core/src/lockfile")
local resolution = require("@commands/pkg/loom-core/src/resolution")
local parser = require("@commands/pkg/loom-core/src/semver/parser")
local solver = require("@commands/pkg/loom-core/src/semver/solver")

local temporaryDirectory = system.tmpdir()
local workingDirectory = path.join(temporaryDirectory, "lute-pkg-resolution")

local function writeConfig(dir: path.Path, name: string, deps: string, workspace: string?)
	local workspaceField = if workspace ~= nil then `,\n\tworkspace = \{{workspace}\n\t}` else ""
	fs.writeStringToFile(
		path.join(dir, "loom.config.luau"),
		`return \{\n\tpackage = \{\n\t\tname = "{name}",\n\t\tversion = "0.0.0",\n\t\tdependencies = \{{deps}\n\t\t},\n\t}{workspaceField},\n}\n`
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

local function resetWorkingDirectory()
	if fs.exists(workingDirectory) then
		fs.removeDirectory(workingDirectory, { recursive = true })
	end
	fs.createDirectory(workingDirectory)
end

test.suite("LoomResolution", function(suite)
	suite:beforeEach(resetWorkingDirectory)

	suite:case("workspaceMembersAppearInLockfile", function(assert)
		local pkgsDir = path.join(workingDirectory, "packages")
		fs.createDirectory(pkgsDir)
		fs.createDirectory(path.join(pkgsDir, "a"))
		fs.createDirectory(path.join(pkgsDir, "b"))
		writeConfig(path.join(pkgsDir, "a"), "a", "")
		writeConfig(path.join(pkgsDir, "b"), "b", "")
		writeConfig(
			workingDirectory,
			"root",
			"",
			[[

		"./packages/a",
		"./packages/b",]]
		)

		local lock = resolution.resolve(path.format(workingDirectory))

		assert.that(lock.members ~= nil)
		local members = lock.members :: any
		assert.eq(members.a.path, "./packages/a")
		assert.eq(members.b.path, "./packages/b")
	end)

	suite:case("workspaceFailsOnDuplicateMemberName", function(assert)
		local pkgsDir = path.join(workingDirectory, "packages")
		fs.createDirectory(pkgsDir)
		fs.createDirectory(path.join(pkgsDir, "one"))
		fs.createDirectory(path.join(pkgsDir, "two"))
		-- Both members declare package.name = "shared"
		writeConfig(path.join(pkgsDir, "one"), "shared", "")
		writeConfig(path.join(pkgsDir, "two"), "shared", "")
		writeConfig(
			workingDirectory,
			"root",
			"",
			[[

		"./packages/one",
		"./packages/two",]]
		)

		local ok, err = pcall(resolution.resolve, path.format(workingDirectory), nil)
		assert.eq(ok, false)
		assert.strContains(tostring(err), "Duplicate workspace member name 'shared'")
	end)

	suite:case("transitiveWorkspaceMembersDoNotLeak", function(assert)
		-- libW is itself a workspace, but we depend on libW only as a path dep.
		-- libW's internal member `libCore` should NOT appear in the root lockfile.
		local libDir = path.join(workingDirectory, "libW")
		fs.createDirectory(libDir)
		fs.createDirectory(path.join(libDir, "core"))
		writeConfig(path.join(libDir, "core"), "libCore", "")
		writeConfig(
			libDir,
			"libW",
			"",
			[[

		"./core",]]
		)

		writeConfig(
			workingDirectory,
			"root",
			[[

			libW = {
				sourceKind = "path",
				source = "./libW",
			},]]
		)

		local lock = resolution.resolve(path.format(workingDirectory))

		assert.that(lock.packages.libW ~= nil)
		assert.eq(lock.members, nil)
		-- libCore is libW's internal member; it should not leak into root's graph
		for _, pkg in lock.packages do
			assert.never.eq(pkg.name, "libCore")
		end
	end)

	suite:case("memberNameCollidesWithPathDep", function(assert)
		local memberDir = path.join(workingDirectory, "internal")
		local extDir = path.join(workingDirectory, "ext")
		fs.createDirectory(memberDir)
		fs.createDirectory(extDir)
		-- Both packages declare package.name = "shared"
		writeConfig(memberDir, "shared", "")
		writeConfig(extDir, "shared", "")

		writeConfig(
			workingDirectory,
			"root",
			[[

			shared = {
				sourceKind = "path",
				source = "./ext",
			},]],
			[[

		"./internal",]]
		)

		local ok, err = pcall(resolution.resolve, path.format(workingDirectory), nil)
		assert.eq(ok, false)
		assert.strContains(tostring(err), "Version conflict")
	end)
end)

test.suite("RegistryResolution", function(suite)
	suite:beforeEach(resetWorkingDirectory)

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

	suite:case("writeLockfilePersistsRegistryEntries", function(assert)
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

		local lock = resolution.resolve(path.format(workingDirectory), universe)
		lockfile.writeFile(lock, path.format(workingDirectory))

		local lockfilePath = path.join(workingDirectory, "loom.lock.luau")
		assert.that(fs.exists(lockfilePath))

		local content = fs.readFileToString(lockfilePath)
		assert.strContains(content, '"registry"')
		assert.strContains(content, "citrus@1.0.0")
	end)
end)
