local fs = require("@std/fs")
local path = require("@std/path")
local system = require("@std/system")
local test = require("@std/test")

local resolution = require("@commands/pkg/loom-core/src/resolution")

local temporaryDirectory = system.tmpdir()
local workingDirectory = path.join(temporaryDirectory, "lute-pkg-resolution")

local function writeConfig(dir: path.Path, name: string, deps: string, workspace: string?)
	local workspaceField = if workspace ~= nil then `,\n\tworkspace = \{{workspace}\n\t}` else ""
	fs.writeStringToFile(
		path.join(dir, "loom.config.luau"),
		`return \{\n\tpackage = \{\n\t\tname = "{name}",\n\t\tversion = "0.0.0",\n\t\tdependencies = \{{deps}\n\t\t},\n\t}{workspaceField},\n}\n`
	)
end

test.suite("LomResolution", function(suite)
	suite:beforeEach(function()
		if fs.exists(workingDirectory) then
			fs.removeDirectory(workingDirectory, { recursive = true })
		end
		fs.createDirectory(workingDirectory)
	end)

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

		local ok, err = pcall(resolution.resolve, path.format(workingDirectory))
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

		local ok, err = pcall(resolution.resolve, path.format(workingDirectory))
		assert.eq(ok, false)
		assert.strContains(tostring(err), "Version conflict")
	end)
end)
