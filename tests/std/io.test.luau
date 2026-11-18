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
		local r = runScript(
			"io_write_basic",
			[[
			local io = require("@std/io")
			io.write("hello")
		]]
		)

		assert.eq(r.exitcode, 0)
		assert.eq(r.stdout, "hello")
	end)

	-- Multiple arguments are concatenated with no separator and no trailing newline.
	suite:case("writeMultipleArgs", function(assert)
		local r = runScript(
			"io_write_multi",
			[[
			local io = require("@std/io")
			io.write("foo", "bar", "baz")
		]]
		)

		assert.eq(r.exitcode, 0)
		assert.eq(r.stdout, "foobarbaz")
	end)

	-- io.write does not append a newline; print() does.
	suite:case("writeNoTrailingNewline", function(assert)
		local r = runScript(
			"io_write_newline",
			[[
			local io = require("@std/io")
			io.write("hello")
		]]
		)

		assert.eq(r.exitcode, 0)
		assert.eq(r.stdout, "hello")
		assert.neq(r.stdout:sub(-1), "\n")
	end)

	-- io.write and print can appear in the same program, but their relative output
	-- order is NOT guaranteed: io.write issues a direct fd-level write via the libuv
	-- thread pool, while print writes to C's buffered FILE* stdout (flushed at exit).
	-- When mixing the two, use strContains rather than exact equality.
	suite:case("writeMixedWithPrint", function(assert)
		local r = runScript(
			"io_write_print",
			[[
			local io = require("@std/io")
			io.write("from-io-write")
			print("from-print")
		]]
		)

		assert.eq(r.exitcode, 0)
		assert.strContains(r.stdout, "from-io-write")
		assert.strContains(r.stdout, "from-print")
	end)

	suite:case("writeEmptyString", function(assert)
		local r = runScript(
			"io_write_empty",
			[[
			local io = require("@std/io")
			io.write("")
			io.write("done")
		]]
		)

		assert.eq(r.exitcode, 0)
		assert.eq(r.stdout, "done")
	end)

	suite:case("writeNoArgs", function(assert)
		local r = runScript(
			"io_write_noargs",
			[[
			local io = require("@std/io")
			io.write()
			io.write("done")
		]]
		)

		assert.eq(r.exitcode, 0)
		assert.eq(r.stdout, "done")
	end)

	suite:case("writeTypeError", function(assert)
		local r = runScript(
			"io_write_typeerr",
			[[
			local io = require("@std/io")
			io.write({} :: any)
		]]
		)

		assert.eq(r.exitcode, 1)
	end)

	-- Many sequential writes must arrive in order without corruption.
	suite:case("writeSequential", function(assert)
		local r = runScript(
			"io_write_sequential",
			[[
			local io = require("@std/io")
			for i = 1, 100 do
			    io.write(tostring(i) .. ",")
			end
		]]
		)

		assert.eq(r.exitcode, 0)
		local expected = ""
		for i = 1, 100 do
			expected ..= tostring(i) .. ","
		end
		assert.eq(r.stdout, expected)
	end)

	suite:case("writeLargeData", function(assert)
		local r = runScript(
			"io_write_large",
			[[
			local io = require("@std/io")
			-- 200 KB: well above the typical pipe-buffer limit of 64 KB.
			io.write(string.rep("x", 200 * 1024))
		]]
		)

		assert.eq(r.exitcode, 0)
		assert.eq(#r.stdout, 200 * 1024)
		assert.eq(r.stdout, string.rep("x", 200 * 1024))
	end)

	-- luaL_checklstring is length-aware, so io.write must pass embedded NUL bytes
	-- through unchanged.
	suite:case("writeNulByteSafe", function(assert)
		local r = runScript(
			"io_write_nul",
			[[
			local io = require("@std/io")
			io.write("a\0b")
		]]
		)

		assert.eq(r.exitcode, 0)
		assert.eq(#r.stdout, 3)
	end)

	-- Runs a script through the system shell with stdout redirected to a file.
	-- No `timeout` option: on Windows it starts the shell detached from the console,
	-- and the child then writes to a new console instead of the redirected file.
	local function runScriptToFile(name: string, script: string): (process.ProcessResult, string)
		local file = path.join(tmpDir, `{name}.luau`)
		local outFile = path.join(tmpDir, `{name}.out`)
		fs.writeStringToFile(file, script)
		local result = process.system(`{lutePath} {path.format(file)} > {path.format(outFile)}`)
		local output = fs.readFileToString(outFile)
		fs.remove(file)
		fs.remove(outFile)
		return result, output
	end

	suite:case("writeToRedirectedFile", function(assert)
		local r, output = runScriptToFile(
			"io_write_file",
			[[
			local io = require("@std/io")
			for i = 1, 3 do
			    io.write(tostring(i) .. ",")
			end
		]]
		)

		assert.eq(r.exitcode, 0)
		assert.eq(output, "1,2,3,")
	end)

	suite:case("writeToRedirectedFileThenExit", function(assert)
		local r, output = runScriptToFile(
			"io_write_file_exit",
			[[
			local io = require("@std/io")
			local process = require("@std/process")
			io.write("before exit")
			process.exit(3)
		]]
		)

		assert.eq(r.exitcode, 3)
		assert.eq(output, "before exit")
	end)
end)
