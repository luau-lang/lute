local luau = require("@std/luau")

type node = luau.AstNode

export type delta =
	{ tag: "append", content: string }
	| { tag: "prepend", content: string }
	| { tag: "replace", content: string }
	| { tag: "remove" }

export type replacement = string | node | { delta }
export type replacements = { [node]: replacement }

return {}
