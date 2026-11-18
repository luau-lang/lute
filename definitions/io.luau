local io = {}

--- Writes one or more strings to standard output without a trailing newline.
function io.write(...: string): ()
	error("unimplemented")
end

--- Writes one or more strings to standard error without a trailing newline.
function io.ewrite(...: string): ()
	error("unimplemented")
end

--- Reads a line from standard input and returns it as a string.
function io.read(): string
	error("unimplemented")
end

return io
