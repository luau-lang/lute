--!strict
-- @std/io
-- stdlib for `@lute/io`
-- Provides standard input, output, and other I/O utility functions

local io = require("@lute/io")

local iolib = {}

--- Reads a line from standard input. If `prompt` is provided, it is printed before waiting for input.
--- User input can be provided via command line stdin, piped input, or redirection from a file. See `examples/user_input.luau`.
function iolib.input(prompt: string?): string
	if prompt then
		-- We temporarily use `print` for prompt until we have proper stdout support, so there is a `\n` between prompt and input.
		print(prompt)
	end
	return io.read()
end

return table.freeze(iolib)
