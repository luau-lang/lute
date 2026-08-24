const configs = require("@commands/lib/configs")
const fs = require("@std/fs")
const parseIgnores = require("@commands/lib/parseIgnores")
const path = require("@std/path")
const system = require("@std/system")
const test = require("@std/test")

const testPath = path.join(system.tmpdir(), "lute_cli_configs_test")
const project = path.join(testPath, "project")

const function writeConfig(directory: path.Path, contents: string)
	fs.createDirectory(directory, { makeParents = true })
	fs.writeStringToFile(path.join(directory, ".config.luau"), contents)
end

test.suite("CliLibConfigs", function(suite)
	suite:beforeEach(function()
		if fs.exists(testPath) then
			fs.removeDirectory(testPath, { recursive = true })
		end
		fs.createDirectory(testPath, { makeParents = true })
	end)

	suite:afterEach(function()
		if fs.exists(testPath) then
			fs.removeDirectory(testPath, { recursive = true })
		end
	end)

	suite:case("reads the requested command's ignores from the nearest config that sets them", function(assert)
		writeConfig(testPath, [[return { lute = { mycommand = { ignores = { "**/vendor/**" } } } }]])
		writeConfig(project, [[return { lute = { othercommand = { ignores = { "**/src/**" } } } }]])

		const ignoreData = configs.findConfiguredIgnores("mycommand", path.format(project))
		assert.that(ignoreData ~= nil, "expected to find ignores configured for mycommand")
		if ignoreData == nil then
			return
		end

		const vendored = path.format(path.join(project, "vendor", "dep.luau"))
		const source = path.format(path.join(project, "src", "main.luau"))
		assert.eq(parseIgnores.isIgnored(ignoreData, vendored, false), true)
		assert.eq(parseIgnores.isIgnored(ignoreData, source, false), false)
	end)

	suite:case("returns nil when no config sets ignores for the command", function(assert)
		writeConfig(project, [[return { lute = { othercommand = { ignores = { "**/src/**" } } } }]])

		assert.eq(configs.findConfiguredIgnores("mycommand", path.format(project)), nil)
	end)

	suite:case("errors when the configured ignores are not an array of filepaths", function(assert)
		writeConfig(project, [[return { lute = { mycommand = { ignores = "**/src/**" } } }]])

		assert.throwsWith("lute.mycommand.ignores must be an array of filepaths", function()
			configs.findConfiguredIgnores("mycommand", path.format(project))
		end)
	end)

	suite:case("errors when an entry in the configured ignores is not a string", function(assert)
		writeConfig(project, [[return { lute = { mycommand = { ignores = { "**/src/**", 5 } } } }]])

		assert.throwsWith("lute.mycommand.ignores[2] must be a string", function()
			configs.findConfiguredIgnores("mycommand", path.format(project))
		end)
	end)
end)
