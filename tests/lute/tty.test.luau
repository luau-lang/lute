local fs = require("@std/fs")
local pathlib = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")
local test = require("@std/test")

local lutePath = pathlib.format(process.execPath())
local tmpDir = system.tmpdir()

-- Tests that need a real TTY are run as subprocesses under `script(1)`,
-- which emulates running a command inside of a terminal. Stdin/out/err get
-- opened as a pty device, which lets us test this.
-- Executing these tests like this, as opposed to snapshot testing is much easier
-- as it avoids multiple levels of process.run indirection
local function runWithPty(name: string, body: string): process.ProcessResult
	local file = pathlib.join(tmpDir, `tty_{name}.luau`)
	fs.writeStringToFile(file, body)
	local invocation = if system.macos
		then `script -q /dev/null {lutePath} {pathlib.format(file)}`
		else `script -q -c "{lutePath} {pathlib.format(file)}" /dev/null`
	local result = process.run({ "sh", "-c", `exec </dev/null; {invocation}` })
	fs.remove(file)
	return result
end

test.suite("TTYSuite", function(suite)
	-- Windows doesn't ship a `script(1)` alternative that makes it easy to test
	if system.win32 then
		return
	end

	-- The remaining cases need a real TTY. We only run them on Unix like machines where
	-- `script(1)` is available to allocate a pty for the child.
	suite:case("onResizeRejectsSecondListener", function(assert)
		local r = runWithPty(
			"second_listener",
			[[
				local tty = require("@lute/tty")
				local handle = tty.open(0)
				handle:onResize(function() end)
				local ok, err = pcall(function()
					handle:onResize(function() end)
				end)
				if ok then
					error("expected second onResize to error")
				end
				if not string.find(tostring(err), "listener already registered") then
					error("unexpected error: " .. tostring(err))
				end
				handle:close()
			]]
		)
		assert.eq(r.exitcode, 0)
	end)

	suite:case("writeReachesTerminal", function(assert)
		local r = runWithPty(
			"write_basic",
			[[
				local tty = require("@lute/tty")
				local handle = tty.open(1)
				handle:write("lute-tty-write-marker")
				handle:close()
			]]
		)
		assert.eq(r.exitcode, 0)
		assert.strContains(r.stdout, "lute-tty-write-marker")
	end)

	suite:case("methodsErrorAfterClose", function(assert)
		local r = runWithPty(
			"after_close",
			[[
				local tty = require("@lute/tty")
				local handle = tty.open(1)
				handle:close()

				local function expectClosed(fn)
					local ok, err = pcall(fn)
					if ok then error("expected error") end
					if not string.find(tostring(err), "tty is closed") then
						error("unexpected error: " .. tostring(err))
					end
				end

				expectClosed(function() handle:write("x") end)
				expectClosed(function() handle:onResize(function() end) end)
			]]
		)
		assert.eq(r.exitcode, 0)
	end)

	suite:case("closeIsIdempotent", function(assert)
		local r = runWithPty(
			"close_idempotent",
			[[
				local tty = require("@lute/tty")
				local handle = tty.open(0)
				handle:close()
				handle:close()
			]]
		)
		assert.eq(r.exitcode, 0)
	end)

	suite:case("freshHandleAcceptsListener", function(assert)
		local r = runWithPty(
			"fresh_listener",
			[[
				local tty = require("@lute/tty")
				local h1 = tty.open(0)
				h1:onResize(function() end)
				h1:close()

				local h2 = tty.open(0)
				h2:onResize(function() end)
				h2:close()
			]]
		)
		assert.eq(r.exitcode, 0)
	end)
end)
