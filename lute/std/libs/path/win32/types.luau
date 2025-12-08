export type pathkind = "unc" | "absolute" | "relative"

export type pathMT = {
	__tostring: () -> string,
}

export type pathdata = {
	parts: { string },
	kind: pathkind,
	drive: string?,
}

export type path = setmetatable<pathdata, pathMT>

export type pathlike = string | pathdata | path

return {}
