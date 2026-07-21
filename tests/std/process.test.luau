local fs = require("@std/fs")
local pathlib = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")
local task = require("@lute/task")
local test = require("@std/test")
local testutil = require("../testutil")
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

		local ex = process.execPath()
		assert.neq(pathlib.format(ex), "")
	end)

	suite:case("runEchoArrayViaRun", function(assert)
		local r = process.run({ "echo", "hello-from-lute" })
		assert.eq(r.stdout, "hello-from-lute\n")
	end)

	suite:case("runPreservesCapturedOutputBytes", function(assert)
		local lutePath = pathlib.format(process.execPath())
		local scriptPath = pathlib.join(system.tmpdir(), "process_binary_stdout.luau")

		fs.writeStringToFile(
			pathlib.format(scriptPath),
			[[
			local io = require("@lute/io")
			io.write("A\r\nB")
		]]
		)

		local r = process.run({ lutePath, pathlib.format(scriptPath) })
		fs.remove(scriptPath)

		assert.eq(r.stdout, "A\r\nB")
	end)

	suite:case("runEchoArrayViaSystem", function(assert)
		local r = process.system("echo hello-from-lute")
		assert.eq(testutil.normalizeLineEndings(r.stdout), "hello-from-lute\n")
	end)

	suite:case("runSystemAndCwd", function(check)
		local rootdir: string = "/"
		local root: pathlib.Path? = nil

		if system.win32 then
			root = pathlib.win32.drive(process.cwd() :: windowsPath.Path)
			rootdir = pathlib.format(root)
		end

		-- LUAUFIX: we shouldn't need to upcast the result of `process.system` to `{ [any]: any }`
		local r = process.run({ "pwd" }, { cwd = rootdir }) :: { [any]: any }

		if system.win32 then
			assert(root ~= nil and (root :: windowsPath.Path).drive ~= nil)
			check.eq(r, {
				exitcode = 0,
				stdout = `/{root.drive:lower()}\n`,
				stderr = "",
				ok = true,
			})
		else
			check.eq(r, {
				exitcode = 0,
				stdout = "/\n",
				stderr = "",
				ok = true,
			})
		end

		-- LUAUFIX: we shouldn't need to upcast the result of `process.system` to `{ [any]: any }`
		local r2 = process.system("echo hello!") :: { [any]: any }
		r2.stdout = testutil.normalizeLineEndings(r2.stdout)
		check.eq(r2, {
			exitcode = 0,
			stdout = "hello!\n",
			stderr = "",
			ok = true,
		})
	end)

	suite:case("runNonzeroExitcode", function(assert)
		-- LUAUFIX: we shouldn't need to upcast the result of `process.run` to `{ [any]: any }`
		local r = process.run({ "sh", "-c", "exit 41" }) :: { [any]: any }
		assert.eq(r, {
			exitcode = 41,
			stdout = "",
			stderr = "",
			ok = false,
		})
	end)

	suite:case("processRunOptionsErrorCases", function(assert)
		assert.throwsWith("process.run requires a non-empty table of arguments", function()
			process.run({})
		end)

		-- All of these tests intentionally pass values of the incorrect
		-- type to `process.run`: this is to ensure that the error
		-- handling on the runtime side is correct (for example, does not
		-- crash because we expected a table and got a string).

		assert.throwsWith("invalid argument #-1 to 'run' (string expected, got table)", function()
			process.run({ "echo", "hello" }, { cwd = {} :: any })
		end)

		assert.throwsWith("invalid argument #-1 to 'run' (string expected, got table)", function()
			process.run({ "echo", "hello" }, { stdio = {} :: any })
		end)

		assert.throwsWith("process option 'env' must be a table", function()
			process.run({ "echo", "hello" }, { env = "not-a-table" :: any })
		end)

		assert.throwsWith("process options must be a table", function()
			process.run({ "echo", "hello" }, "invalid_option" :: any)
		end)

		assert.throwsWith("process options must be a table", function()
			process.run({ "echo", "hello" }, "not-a-table" :: any)
		end)

		assert.throwsWith("process.run requires a non-empty table of arguments", function()
			process.run({ huh = 42 })
		end)
	end)

	suite:case("processRunArraylikeTable", function(assert)
		-- We expect this to still work and ignore the non-string keys
		local r = process.run({ "echo", "hello", foo = "bar" })
		assert.eq(r.stdout, "hello\n")
	end)

	suite:case("runChildReadingStdinDoesNotHang", function(assert)
		local lutePath = pathlib.format(process.execPath())
		local tmpDir = system.tmpdir()
		local scriptPath = pathlib.join(tmpDir, "process_stdin_eof.luau")

		fs.writeStringToFile(
			pathlib.format(scriptPath),
			[[
			local io = require("@std/io")
			local ok = pcall(function()
				io.input()
			end)
			if ok then
				print("read-succeeded-unexpectedly")
			else
				print("saw-eof")
			end
		]]
		)

		local r = process.run({ lutePath, pathlib.format(scriptPath) })
		fs.remove(scriptPath)

		assert.strContains(r.stdout, "saw-eof")
	end)

	suite:case("runTimesOutProcess", function(assert)
		local r = process.run({ "sleep", "10" }, { timeout = 0.2 })
		assert.eq(r.ok, false)
		assert.that(r.timedOut)
	end)

	suite:case("runExitsBeforeTimeout", function(assert)
		local r = process.run({ "echo", "hello" }, { timeout = 5 })
		assert.that(r.ok)
		assert.eq(r.timedOut, nil)
		assert.eq(r.stdout, "hello\n")
	end)

	suite:case("systemTimesOutProcess", function(assert)
		local r = process.system("sleep 10", { timeout = 0.2 })
		assert.eq(r.ok, false)
		assert.that(r.timedOut)
	end)

	suite:case("timeoutKillsProcessGroup", function(assert)
		local tmpFile = pathlib.join(system.tmpdir(), "lute_timeout_group_test.txt")
		local tmpFileStr = pathlib.format(tmpFile)
		-- Spawn a shell that starts a background child writing to a file
		local r =
			process.system(`sh -c 'while true; do echo tick >> {tmpFileStr}; sleep 0.05; done'`, { timeout = 0.3 })
		assert.that(r.timedOut)

		-- Wait briefly, then check the file stopped growing
		task.wait(0.2)
		local contentAfter = fs.readFileToString(tmpFile)
		task.wait(0.2)
		local contentLater = fs.readFileToString(tmpFile)
		assert.eq(contentAfter, contentLater)

		-- Cleanup
		fs.remove(tmpFile)
	end)

	suite:case("processSystemOptionsErrorCases", function(assert)
		-- All of these tests intentionally pass values of the incorrect
		-- type to `process.system`: this is to ensure that the error
		-- handling on the runtime side is correct (for example, does not
		-- crash because we expected a table and got a string).

		assert.throwsWith("invalid argument #1 to 'system' (string expected, got nil)", function()
			(process.system :: any)()
		end)

		assert.throwsWith("invalid argument #1 to 'system' (string expected, got table)", function()
			process.system({} :: any)
		end)

		assert.throwsWith("invalid argument #-1 to 'system' (string expected, got table)", function()
			process.system("echo hello", { system = {} :: any })
		end)

		assert.throwsWith("invalid argument #-1 to 'system' (string expected, got table)", function()
			process.system("echo hello", { cwd = {} :: any })
		end)
		assert.throwsWith("invalid argument #-1 to 'system' (string expected, got table)", function()
			process.system("echo hello", { stdio = {} :: any })
		end)

		assert.throwsWith("process option 'env' must be a table", function()
			process.system("echo hello", { env = "not-a-table" :: any })
		end)

		assert.throwsWith("process options must be a table", function()
			process.system("echo hello", "invalid_option" :: any)
		end)
	end)
end)
