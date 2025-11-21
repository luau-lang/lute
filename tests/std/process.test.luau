local pathlib = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")
local stringext = require("@std/stringext")
local test = require("@std/test")

local function compareStrings(result: string, expected: string)
	for i = 1, math.max(#result, #expected) do
		local rChar = result:sub(i, i):byte()
		local eChar = expected:sub(i, i):byte()
		if rChar ~= eChar then
			print(`Difference at index {i}: result='{rChar}', expected='{eChar}'`)
		end
	end
end

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
		local ok, err = pcall(function()
			process.run()
		end)
		assert.neq(ok, true)
		local expectedError = "process.run expects a table of arguments as the first parameter"
		-- pcall inserts the filename and line number before the actual error message in `err`, so we check suffix only
		assert.eq(stringext.hassuffix(tostring(err), expectedError), true)

		ok, err = pcall(function()
			process.run({})
		end)
		assert.neq(ok, true)
		expectedError = "process.run requires a non-empty table of arguments"
		assert.eq(stringext.hassuffix(tostring(err), expectedError), true)

		ok, err = pcall(function()
			process.run({ "echo", "hello" }, { cwd = {} })
		end)
		assert.neq(ok, true)
		expectedError = "process option 'cwd' must be a string"
		assert.eq(stringext.hassuffix(tostring(err), expectedError), true)

		ok, err = pcall(function()
			process.run({ "echo", "hello" }, { stdio = {} })
		end)
		assert.neq(ok, true)
		expectedError = "process option 'stdio' must be a string"
		assert.eq(stringext.hassuffix(tostring(err), expectedError), true)

		ok, err = pcall(function()
			process.run({ "echo", "hello" }, { env = "not-a-table" })
		end)
		assert.neq(ok, true)
		expectedError = "process option 'env' must be a table"
		assert.eq(stringext.hassuffix(tostring(err), expectedError), true)
	end)

	suite:case("process_system_options_error_cases", function(assert)
		local ok, err = pcall(function()
			process.system()
		end)
		assert.neq(ok, true)
		local expectedError = "invalid argument #1 to 'system' (string expected, got nil)"
		-- pcall inserts the filename and line number before the actual error message in `err`, so we check suffix only
		assert.eq(stringext.hassuffix(tostring(err), expectedError), true)

		ok, err = pcall(function()
			process.system({})
		end)
		assert.neq(ok, true)
		expectedError = "invalid argument #1 to 'system' (string expected, got table)"
		assert.eq(stringext.hassuffix(tostring(err), expectedError), true)

		ok, err = pcall(function()
			process.system("echo hello", { system = {} })
		end)
		assert.neq(ok, true)
		expectedError = "process.system option 'system' must be a string"
		assert.eq(stringext.hassuffix(tostring(err), expectedError), true)

		ok, err = pcall(function()
			process.system("echo hello", { cwd = {} })
		end)
		assert.neq(ok, true)
		expectedError = "process option 'cwd' must be a string"
		assert.eq(stringext.hassuffix(tostring(err), expectedError), true)

		ok, err = pcall(function()
			process.system("echo hello", { stdio = {} })
		end)
		assert.neq(ok, true)
		expectedError = "process option 'stdio' must be a string"
		assert.eq(stringext.hassuffix(tostring(err), expectedError), true)

		ok, err = pcall(function()
			process.system("echo hello", { env = "not-a-table" })
		end)
		assert.neq(ok, true)
		expectedError = "process option 'env' must be a table"
		assert.eq(stringext.hassuffix(tostring(err), expectedError), true)
	end)
end)

test.run()
