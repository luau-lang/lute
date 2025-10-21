export type win32pathkind = "unc" | "absolute" | "relative"

export type posixpath = {
	parts: { string },
	absolute: boolean,
}

export type win32path = {
	parts: { string },
	kind: win32pathkind,
	driveLetter: string?,
}

export type posixpathlike = string | posixpath
export type win32pathlike = string | win32path

export type path = posixpath | win32path
export type pathlike = string | path

return {}
