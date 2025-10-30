export type pathinterface = {
	__tostring: () -> string,
}

export type path = {
	parts: { string },
	absolute: boolean,
}

export type pathlike = string | path

return {}
