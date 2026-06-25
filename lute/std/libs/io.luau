--!strict
-- @std/io
-- stdlib for `@lute/io`
-- Provides standard input, output, and other I/O utility functions

local io = require("@lute/io")

local iolib = {}

--- Writes one or more strings to standard output without a trailing newline.
function iolib.write(...: string): ()
	io.write(...)
end

--- Reads a line from standard input. If `prompt` is provided, it is written to stdout before waiting for input.
--- User input can be provided via command line stdin, piped input, or redirection from a file. See `examples/user_input.luau`.
function iolib.input(prompt: string?): string
	if prompt then
		io.write(prompt)
	end

	local line = io.read()

	-- io.read() returns the raw bytes from stdin, including the trailing line
	-- terminator. Strip a single terminator so callers get a clean string usable
	-- directly with filesystem APIs. Handles "\r\n" (Windows) and "\n" (Unix), as
	-- well as a stray trailing "\r", while preserving any interior or leading
	-- whitespace.
	if line:sub(-2) == "\r\n" then
		return line:sub(1, -3)
	elseif line:sub(-1) == "\n" or line:sub(-1) == "\r" then
		return line:sub(1, -2)
	end

	return line
end

return table.freeze(iolib)
