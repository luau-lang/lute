export type pathkind = "unc" | "absolute" | "relative"

export type path = {
	parts: { string },
	kind: pathkind,
	driveLetter: string?,
}

export type pathlike = string | path

return { "successfully exported win32 path types" }
