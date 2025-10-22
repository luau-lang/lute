local test = require("@std/test")
local process = require("@std/process")

test.suite("ProcessSuite", function(suite)
	suite:case("homedir_and_cwd_and_execpath", function(assert)
		local hd = process.homedir()
		assert.eq(hd ~= nil, true)

		local cwd = process.cwd()
		assert.eq(cwd ~= nil, true)

		local ex = process.execpath()
		assert.eq(ex ~= nil, true)
	end)

	suite:case("run_echo_array", function(assert)
		local r = process.run({ "echo", "hello-from-lute" })
		assert.eq(r.exitcode, 0)
		assert.eq(type(r.stdout) == "string", true)
		assert.eq(r.ok, true)
	end)

	suite:case("run_shell_and_env_and_cwd", function(assert)
		local r = process.run({ "pwd" }, { cwd = "/" })
		assert.eq(r.exitcode, 0)
		assert.eq(r.stdout, "/\n")

		local r2 = process.run({ "echo", "$HOME" }, { env = { HOME = "/home/lute" }, shell = true })
		assert.eq(r2.exitcode, 0)
		assert.eq(r2.stdout, "/home/lute\n")
	end)

	suite:case("run_nonzero_exitcode", function(assert)
		local r = process.run({ "sh", "-c", "exit 41" })
		assert.eq(r.exitcode, 41)
		assert.eq(r.ok, false)
	end)

	-- uncomment to test process.exit (will terminate the test runner)
	-- suite:case("process_exit", function(assert)
	--     local ok, err = pcall(function() process.exit(0) end)
	--     assert.eq(ok, false)
	-- end)
end)

test.run()
