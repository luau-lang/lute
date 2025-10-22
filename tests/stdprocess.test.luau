local test = require("@std/test")
local process = require("@std/process")
local path = require("@std/path")
local fs = require("@std/fs")

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
        local tmp = "tmp"
        if not fs.exists(tmp) then
            fs.mkdir(tmp)
        end
        fs.writestringtofile(path.join(tmp, "file.txt"), "p")

        local r = process.run("pwd", { cwd = tmp, shell = true })
        assert.eq(r.exitcode, 0)
        assert.eq(type(r.stdout) == "string", true)

        local r2 = process.run("echo $LUTE_TEST_ENV", { shell = true, env = { LUTE_TEST_ENV = "works" } })
        assert.eq(r2.exitcode, 0)
        assert.eq(string.find(r2.stdout, "works") ~= nil, true)

        fs.remove(path.join(tmp, "file.txt"))
        fs.rmdir(tmp)
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
