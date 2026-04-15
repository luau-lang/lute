local io = {}

function io.write(...: string): ()
	error("unimplemented")
end

function io.read(): string
	error("unimplemented")
end

function io.flush(): ()
	error("unimplemented")
end

return io
