export type diffoperation = {
	key: "EQUAL" | "ADD" | "DELETE",
	text: string,
}

export type diff = { diffoperation }

export type diffoptions = {
	byChar: boolean?,
}?

return table.freeze({})
