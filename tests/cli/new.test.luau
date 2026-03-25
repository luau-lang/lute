local fs = require("@std/fs")
local pathlib = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")
local test = require("@std/test")

local tmpdir = system.tmpdir()
local workdir = pathlib.join(tmpdir, "lute-new")
local lutePath = pathlib.format(process.execpath())
local projectName = "myproject"
local projectDir = pathlib.join(workdir, projectName)

test.suite("LuteNew", function(suite)
	suite:beforeeach(function()
		if fs.exists(workdir) then
			fs.removedirectory(workdir, { recursive = true })
		end
		fs.createdirectory(workdir)
	end)

	suite:case("createsProjectDirectory", function(assert)
		local result = process.run({ lutePath, "new", projectName }, { cwd = pathlib.format(workdir) })

		assert.eq(result.exitcode, 0)
		assert.that(fs.exists(pathlib.join(workdir, projectName)))
	end)

	suite:case("createsMainScript", function(assert)
		process.run({ lutePath, "new", projectName }, { cwd = pathlib.format(workdir) })

		local mainPath = pathlib.join(workdir, projectName, "main.luau")
		assert.that(fs.exists(mainPath))
		local contents = fs.readfiletostring(mainPath)
		assert.strcontains(contents, "Hello, world!")
	end)

	suite:case("createsTestScript", function(assert)
		process.run({ lutePath, "new", projectName }, { cwd = pathlib.format(workdir) })

		local testPath = pathlib.join(workdir, projectName, "main.test.luau")
		assert.that(fs.exists(testPath))
		local contents = fs.readfiletostring(testPath)
		assert.strcontains(contents, "@std/test")
	end)

	suite:case("createsConfigFile", function(assert)
		process.run({ lutePath, "new", projectName }, { cwd = pathlib.format(workdir) })

		local configPath = pathlib.join(workdir, projectName, ".config.luau")
		assert.that(fs.exists(configPath))
		local contents = fs.readfiletostring(configPath)
		assert.strcontains(contents, "strict")
	end)

	suite:case("printSuccessMessage", function(assert)
		local result = process.run({ lutePath, "new", projectName }, { cwd = pathlib.format(workdir) })

		assert.eq(result.exitcode, 0)
		assert.strcontains(result.stdout, "Created project 'myproject'")
	end)

	suite:case("failsWhenNoProjectNameGiven", function(assert)
		local result = process.run({ lutePath, "new" }, { cwd = pathlib.format(workdir) })

		assert.eq(result.exitcode, 1)
		assert.strcontains(result.stdout, "Missing required argument <project-name>")
	end)

	suite:case("failsWhenDirectoryAlreadyExists", function(assert)
		fs.createdirectory(pathlib.join(workdir, projectName))

		local result = process.run({ lutePath, "new", projectName }, { cwd = pathlib.format(workdir) })

		assert.eq(result.exitcode, 1)
		assert.strcontains(result.stdout, "already exists")
	end)

	suite:case("showsHelpWithFlag", function(assert)
		local result = process.run({ lutePath, "new", "--help" }, { cwd = pathlib.format(workdir) })

		assert.eq(result.exitcode, 0)
		assert.strcontains(result.stdout, "Usage: lute new <project-name>")
	end)

	suite:case("typechecksOutOfTheBox", function(assert)
		local result = process.run({ lutePath, "new", projectName }, { cwd = pathlib.format(workdir) })
		assert.eq(result.exitcode, 0)

		-- Now, let's try typechecking this project
		local r2 = process.run({ lutePath, "check", "main.luau" }, { cwd = pathlib.format(projectDir) })
		assert.eq(r2.exitcode, 0)
	end)

	suite:case("passesTestsOutOfTheBox", function(assert)
		local result = process.run({ lutePath, "new", projectName }, { cwd = pathlib.format(workdir) })
		assert.eq(result.exitcode, 0)

		-- Now, let's run all of the tests as well (this should pass because there are no tests in empty projects)
		local r2 = process.run({ lutePath, "test" }, { cwd = pathlib.format(projectDir) })
		assert.eq(r2.exitcode, 0)
	end)
end)
