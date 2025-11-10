local luau = require("@std/luau")

type node = luau.AstNode

export type delta =
	| { tag: "append", content: string | node }
	| { tag: "prepend", content: string | node }
	| { tag: "replace", content: string | node }
	| { tag: "remove" }

export type replacement = string | node | delta
export type replacements = { [node]: replacement }

return {}
