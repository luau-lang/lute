local fs = require("@std/fs")
local pathlib = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")
local test = require("@std/test")

local tmpdir = system.tmpdir()

local rundir = pathlib.join(tmpdir, "lute-run")

local lutePath = pathlib.format(process.execpath())

test.suite("lute-run", function(suite)
	suite:beforeeach(function()
		if fs.exists(rundir) then
			fs.removedirectory(rundir, { recursive = true })
		end
	end)

	suite:case("same-named file and directory", function(assert)
		-- Setup
		fs.createdirectory(rundir)
		fs.createdirectory(pathlib.join(rundir, "hello"))

		local helloFilePath = pathlib.join(rundir, "hello.luau")
		fs.writestringtofile(helloFilePath, "print('Hello world')")

		-- Execute
		local result = process.run({ lutePath, pathlib.format(helloFilePath) })

		assert.eq(result.exitcode, 1)
		assert.neq(
			result.stderr:find(
				"Error while resolving filepath '.+/hello%.luau': Unable to tell whether path is a file or directory%. Is there a same%-named file or directory%?"
			),
			nil
		)
		assert.strnotcontains(result.stdout, "Hello world")
	end)
end)

test.run()
