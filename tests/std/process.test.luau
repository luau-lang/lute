local pathlib = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")
local test = require("@std/test")
local windowsPath = require("@std/path/win32")

test.suite("ProcessSuite", function(suite)
	suite:case("processArgsIsTable", function(assert)
		assert.eq(type(process.args), "table")
	end)

	suite:case("homedirAndCwdAndExecpath", function(assert)
		local hd = process.homedir()
		assert.neq(pathlib.format(hd), "")

		local cwd = process.cwd()
		assert.neq(pathlib.format(cwd), "")

		local ex = process.execpath()
		assert.neq(pathlib.format(ex), "")
	end)

	suite:case("runEchoArrayViaRun", function(assert)
		local r = process.run({ "echo", "hello-from-lute" })
		assert.eq(r.stdout, "hello-from-lute\n")
	end)

	suite:case("runEchoArrayViaSystem", function(assert)
		local r = process.system("echo hello-from-lute")
		assert.eq(r.stdout, "hello-from-lute\n")
	end)

	suite:case("runSystemAndCwd", function(check)
		local rootdir: string = "/"
		local root: pathlib.path? = nil

		if system.win32 then
			root = pathlib.win32.drive(process.cwd() :: windowsPath.path)
			rootdir = pathlib.format(root)
		end

		-- LUAUFIX: we shouldn't need to upcast the result of `process.system` to `{ [any]: any }`
		local r = process.run({ "pwd" }, { cwd = rootdir }) :: { [any]: any }

		if system.win32 then
			assert(root ~= nil and (root :: windowsPath.path).drive ~= nil)
			check.tableeq(r, {
				exitcode = 0,
				stdout = `/{root.drive:lower()}\n`,
				stderr = "",
				ok = true,
			})
		else
			check.tableeq(r, {
				exitcode = 0,
				stdout = "/\n",
				stderr = "",
				ok = true,
			})
		end

		-- LUAUFIX: we shouldn't need to upcast the result of `process.system` to `{ [any]: any }`
		local r2 = process.system("echo hello!") :: { [any]: any }
		check.tableeq(r2, {
			exitcode = 0,
			stdout = "hello!\n",
			stderr = "",
			ok = true,
		})
	end)

	suite:case("runNonzeroExitcode", function(assert)
		-- LUAUFIX: we shouldn't need to upcast the result of `process.run` to `{ [any]: any }`
		local r = process.run({ "sh", "-c", "exit 41" }) :: { [any]: any }
		assert.tableeq(r, {
			exitcode = 41,
			stdout = "",
			stderr = "",
			ok = false,
		})
	end)

	suite:case("processRunOptionsErrorCases", function(assert)
		assert.erroreq(function()
			process.run({})
		end, "process.run requires a non-empty table of arguments")

		-- All of these tests intentionally pass values of the incorrect
		-- type to `process.run`: this is to ensure that the error
		-- handling on the runtime side is correct (for example, does not
		-- crash because we expected a table and got a string).

		assert.erroreq(function()
			process.run({ "echo", "hello" }, { cwd = {} :: any })
		end, "invalid argument #-1 to 'run' (string expected, got table)")

		assert.erroreq(function()
			process.run({ "echo", "hello" }, { stdio = {} :: any })
		end, "invalid argument #-1 to 'run' (string expected, got table)")

		assert.erroreq(function()
			process.run({ "echo", "hello" }, { env = "not-a-table" :: any })
		end, "process option 'env' must be a table")

		assert.erroreq(function()
			process.run({ "echo", "hello" }, "invalid_option" :: any)
		end, "process options must be a table")

		assert.erroreq(function()
			process.run({ "echo", "hello" }, "not-a-table" :: any)
		end, "process options must be a table")

		assert.erroreq(function()
			process.run({ huh = 42 })
		end, "process.run requires a non-empty table of arguments")
	end)

	suite:case("processRunArraylikeTable", function(assert)
		-- We expect this to still work and ignore the non-string keys
		local r = process.run({ "echo", "hello", foo = "bar" })
		assert.eq(r.stdout, "hello\n")
	end)

	suite:case("processSystemOptionsErrorCases", function(assert)
		-- All of these tests intentionally pass values of the incorrect
		-- type to `process.system`: this is to ensure that the error
		-- handling on the runtime side is correct (for example, does not
		-- crash because we expected a table and got a string).

		assert.erroreq(function()
			(process.system :: any)()
		end, "invalid argument #1 to 'system' (string expected, got nil)")

		assert.erroreq(function()
			process.system({} :: any)
		end, "invalid argument #1 to 'system' (string expected, got table)")

		assert.erroreq(function()
			process.system("echo hello", { system = {} :: any })
		end, "invalid argument #-1 to 'system' (string expected, got table)")

		assert.erroreq(function()
			process.system("echo hello", { cwd = {} :: any })
		end, "invalid argument #-1 to 'system' (string expected, got table)")
		assert.erroreq(function()
			process.system("echo hello", { stdio = {} :: any })
		end, "invalid argument #-1 to 'system' (string expected, got table)")

		assert.erroreq(function()
			process.system("echo hello", { env = "not-a-table" :: any })
		end, "process option 'env' must be a table")

		assert.erroreq(function()
			process.system("echo hello", "invalid_option" :: any)
		end, "process options must be a table")
	end)
end)
