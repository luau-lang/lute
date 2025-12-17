export type diffoperationkey = "EQUAL" | "ADD" | "DELETE"

export type diffoperation = {
	key: diffoperationkey,
	text: string,
}

export type diff = { diffoperation }

export type diffoptions = {
	byChar: boolean?,
}?

return table.freeze({})
