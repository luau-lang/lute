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
	return io.read()
end

return table.freeze(iolib)
