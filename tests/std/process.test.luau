local pathlib = require("@std/path")
local process = require("@std/process")
local test = require("@std/test")
local system = require("@std/system")
test.suite("ProcessSuite", function(suite)
	suite:case("homedir_and_cwd_and_execpath", function(assert)
		local hd = process.homedir()
		assert.neq(pathlib.format(hd), "")

		local cwd = process.cwd()
		assert.neq(pathlib.format(cwd), "")

		local ex = process.execpath()
		assert.neq(pathlib.format(ex), "")
	end)

	suite:case("run_echo_array", function(assert)
		local r = process.run({ "echo", "hello-from-lute" })
		assert.eq(r.stdout, "hello-from-lute\n")
	end)

	suite:case("run_shell_and_cwd", function(assert)
		local rootdir: string = "/"
		if system.win32 then
			local root = pathlib.win32.drive(process.cwd())
			rootdir = pathlib.format(root)
		end
		local r = process.run({ "pwd" }, { cwd = rootdir, shell = if system.win32 then "cmd" else "bash" })
		assert.tableeq(r, {
			exitcode = 0,
			stdout = "/\n",
			stderr = "",
			ok = true,
		})

		local r2 = process.run({ "echo hello!" }, { shell = true })
		assert.tableeq(r2, {
			exitcode = 0,
			stdout = "hello!\n",
			stderr = "",
			ok = true,
		})
	end)

	suite:case("run_nonzero_exitcode", function(assert)
		local r = process.run({ "sh", "-c", "exit 41" })
		assert.tableeq(r, {
			exitcode = 41,
			stdout = "",
			stderr = "",
			ok = false,
		})
	end)
end)

test.run()
