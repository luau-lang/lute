--!strict
local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")
local test = require("@std/test")

local lutePath = path.format(process.execPath())
local tmpDir = system.tmpdir()

local function runScript(name: string, script: string): process.ProcessResult
	local file = path.join(tmpDir, `{name}.luau`)
	fs.writeStringToFile(file, script)
	local result = process.run({ lutePath, path.format(file) })
	fs.remove(file)
	return result
end

test.suite("IoWriteSuite", function(suite)
	-- Basic: single string argument, no trailing newline.
	suite:case("writeBasic", function(assert)
		local r = runScript("io_write_basic", [[
local io = require("@std/io")
io.write("hello")
]])
		assert.eq(r.exitcode, 0)
		assert.eq(r.stdout, "hello")
	end)

	-- Multiple arguments are concatenated with no separator and no trailing newline.
	suite:case("writeMultipleArgs", function(assert)
		local r = runScript("io_write_multi", [[
local io = require("@std/io")
io.write("foo", "bar", "baz")
]])
		assert.eq(r.exitcode, 0)
		assert.eq(r.stdout, "foobarbaz")
	end)

	-- io.write does not append a newline; print() does.
	suite:case("writeNoTrailingNewline", function(assert)
		local r = runScript("io_write_newline", [[
local io = require("@std/io")
io.write("hello")
]])
		assert.eq(r.exitcode, 0)
		assert.eq(r.stdout, "hello")
		assert.neq(r.stdout:sub(-1), "\n")
	end)

	-- io.write and print can appear in the same program, but their relative output
	-- order is NOT guaranteed: io.write issues a direct fd-level write via the libuv
	-- thread pool, while print writes to C's buffered FILE* stdout (flushed at exit).
	-- When mixing the two, use strContains rather than exact equality.
	suite:case("writeMixedWithPrint", function(assert)
		local r = runScript("io_write_print", [[
local io = require("@std/io")
io.write("from-io-write")
print("from-print")
]])
		assert.eq(r.exitcode, 0)
		assert.strContains(r.stdout, "from-io-write")
		assert.strContains(r.stdout, "from-print")
	end)

	-- io.write("") takes the early-return path (no yield) and produces no output.
	-- Note: this means io.write("") is synchronous while io.write("x") yields —
	-- a minor behavioural inconsistency documented here.
	suite:case("writeEmptyString", function(assert)
		local r = runScript("io_write_empty", [[
local io = require("@std/io")
io.write("")
io.write("done")
]])
		assert.eq(r.exitcode, 0)
		assert.eq(r.stdout, "done")
	end)

	-- io.write() with no arguments also takes the early-return path.
	suite:case("writeNoArgs", function(assert)
		local r = runScript("io_write_noargs", [[
local io = require("@std/io")
io.write()
io.write("done")
]])
		assert.eq(r.exitcode, 0)
		assert.eq(r.stdout, "done")
	end)

	-- Numbers are coerced to strings by luaL_checklstring (Lua convention), so
	-- io.write(42) succeeds and writes "42". A truly non-coercible type such as a
	-- table must be used to trigger a runtime error.
	suite:case("writeTypeError", function(assert)
		local r = runScript("io_write_typeerr", [[
local io = require("@std/io")
io.write({} :: any)
]])
		assert.eq(r.exitcode, 1)
	end)

	-- Many sequential writes must arrive in order without corruption.
	-- Each write constructs a fresh IOWrite/uv_fs_t; uv_fs_req_cleanup is invoked
	-- via ~UVRequest() on completion. This confirms there is no state leak between
	-- successive calls.
	suite:case("writeSequential", function(assert)
		local r = runScript("io_write_sequential", [[
local io = require("@std/io")
for i = 1, 100 do
    io.write(tostring(i) .. ",")
end
]])
		assert.eq(r.exitcode, 0)
		local expected = ""
		for i = 1, 100 do
			expected ..= tostring(i) .. ","
		end
		assert.eq(r.stdout, expected)
	end)

	-- A single io.write call with >64 KB of data exercises the uv_fs_write
	-- thread-pool path. When stdout is a pipe and the kernel returns a partial
	-- write, execution reaches the retry loop in writeCallback.
	--
	-- Bug: the partial-write retry reuses the uv_fs_t without calling
	-- uv_fs_req_cleanup first, violating the libuv API contract. Under ASan/MSan
	-- or on platforms where cleanup is not a no-op for fs-write requests, this
	-- causes undefined behaviour.
	--
	-- A secondary bug: if uv_fs_write ever returns 0 bytes written (no error),
	-- the retry loop spins forever. That condition cannot be forced reliably
	-- against a blocking fd, but a hang here would indicate it.
	suite:case("writeLargeData", function(assert)
		local r = runScript("io_write_large", [[
local io = require("@std/io")
-- 200 KB: well above the typical pipe-buffer limit of 64 KB.
io.write(string.rep("x", 200 * 1024))
]])
		assert.eq(r.exitcode, 0)
		assert.eq(#r.stdout, 200 * 1024)
		assert.eq(r.stdout, string.rep("x", 200 * 1024))
	end)

	-- luaL_checklstring is length-aware, so io.write must pass embedded NUL bytes
	-- through unchanged.
	suite:case("writeNulByteSafe", function(assert)
		local r = runScript("io_write_nul", [[
local io = require("@std/io")
io.write("a\0b")
]])
		assert.eq(r.exitcode, 0)
		assert.eq(#r.stdout, 3)
	end)

	-- io.input's prompt must arrive without a trailing newline. Prior to this PR,
	-- print(prompt) was used, which appended '\n' and left an awkward blank line
	-- between the prompt and the user's input. The fix replaced it with
	-- io.write(prompt).
	suite:case("writePromptNoNewline", function(assert)
		local r = runScript("io_write_prompt", [[
local io = require("@std/io")
io.write("Enter value: ")
]])
		assert.eq(r.exitcode, 0)
		assert.eq(r.stdout, "Enter value: ")
		assert.that(r.stdout:find("\n", 1, true) == nil)
	end)
end)
