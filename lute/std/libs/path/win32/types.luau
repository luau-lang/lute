export type pathkind = "unc" | "absolute" | "relative"

export type pathinterface = {
	__tostring: () -> string,
}

export type path = {
	parts: { string },
	kind: pathkind,
	driveLetter: string?,
}

export type pathlike = string | path

return {}
