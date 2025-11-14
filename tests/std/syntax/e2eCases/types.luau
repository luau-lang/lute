local luau = require("@lute/luau")

export type Transform = (luau.AstStatBlock) -> string

export type Case = { initial: string, expected: string }

export type e2e = {
	transform: Transform,
	cases: { Case },
}

return table.freeze({})
