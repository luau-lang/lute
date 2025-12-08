export type pathMT = {
	__tostring: () -> string,
}

export type pathdata = {
	parts: { string },
	absolute: boolean,
}

export type path = setmetatable<pathdata, pathMT>

export type pathlike = string | path | pathdata

return {}
