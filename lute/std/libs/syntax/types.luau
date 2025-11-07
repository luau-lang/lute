local luau = require("@std/luau")

type node = luau.AstNode

export type removal = { tag: "remove" }

export type delta =
	| { tag: "append", content: string | node }
	| { tag: "prepend", content: string | node }
	| { tag: "replace", content: string | node }

export type replacement = string | node | removal | delta | { delta }
export type replacements = { [node]: replacement }

return {}
