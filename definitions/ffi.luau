local ffi = {
	c = {},
}

function ffi.c.testadd(a: number, b: number): number
	error("not implemented")
end

return ffi
