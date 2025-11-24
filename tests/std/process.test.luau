local pathlib = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")
local test = require("@std/test")

test.suite("ProcessSuite", function(suite)
	suite:case("homedir_and_cwd_and_execpath", function(assert)
		local hd = process.homedir()
		assert.neq(pathlib.format(hd), "")

		local cwd = process.cwd()
		assert.neq(pathlib.format(cwd), "")

		local ex = process.execpath()
		assert.neq(pathlib.format(ex), "")
	end)

	suite:case("run_echo_array_via_run", function(assert)
		local r = process.run({ "echo", "hello-from-lute" })
		assert.eq(r.stdout, "hello-from-lute\n")
	end)

	suite:case("run_echo_array_via_system", function(assert)
		local r = process.system("echo hello-from-lute")
		assert.eq(r.stdout, "hello-from-lute\n")
	end)

	suite:case("run_system_and_cwd", function(check)
		local rootdir: string = "/"
		local root: pathlib.path? = nil
		if system.win32 then
			root = pathlib.win32.drive(process.cwd())
			rootdir = pathlib.format(root)
		end
		local r = process.run({ "pwd" }, { cwd = rootdir })
		if system.win32 then
			assert(root ~= nil and root.driveLetter ~= nil)
			check.tableeq(r, {
				exitcode = 0,
				stdout = `/{root.driveLetter:lower()}\n`,
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

		local r2 = process.system("echo hello!")
		check.tableeq(r2, {
			exitcode = 0,
			stdout = "hello!\n",
			stderr = "",
			ok = true,
		})
	end)

	suite:case("run_nonzero_exitcode", function(assert)
		local r = process.system("sh -c 'exit 41'")
		assert.tableeq(r, {
			exitcode = 41,
			stdout = "",
			stderr = "",
			ok = false,
		})
	end)

	suite:case("process_run_options_error_cases", function(assert)
		assert.erroreq(function()
			process.run({})
		end, "process.run requires a non-empty table of arguments")

		assert.erroreq(function()
			process.run({ "echo", "hello" }, { cwd = {} })
		end, "invalid argument #-1 to 'run' (string expected, got table)")

		assert.erroreq(function()
			process.run({ "echo", "hello" }, { stdio = {} })
		end, "invalid argument #-1 to 'run' (string expected, got table)")

		assert.erroreq(function()
			process.run({ "echo", "hello" }, { env = "not-a-table" })
		end, "process option 'env' must be a table")

		assert.erroreq(function()
			process.run({ "echo", "hello" }, "invalid_option")
		end, "process options must be a table")

		assert.erroreq(function()
			process.run({ "echo", "hello" }, "not-a-table")
		end, "process options must be a table")
	end)

	suite:case("process_system_options_error_cases", function(assert)
		assert.erroreq(function()
			process.system()
		end, "invalid argument #1 to 'system' (string expected, got nil)")

		assert.erroreq(function()
			process.system({})
		end, "invalid argument #1 to 'system' (string expected, got table)")

		assert.erroreq(function()
			process.system("echo hello", { system = {} })
		end, "invalid argument #-1 to 'system' (string expected, got table)")

		assert.erroreq(function()
			process.system("echo hello", { cwd = {} })
		end, "invalid argument #-1 to 'system' (string expected, got table)")
		assert.erroreq(function()
			process.system("echo hello", { stdio = {} })
		end, "invalid argument #-1 to 'system' (string expected, got table)")

		assert.erroreq(function()
			process.system("echo hello", { env = "not-a-table" })
		end, "process option 'env' must be a table")

		assert.erroreq(function()
			process.system("echo hello", "invalid_option")
		end, "process options must be a table")
	end)
end)

test.run()
