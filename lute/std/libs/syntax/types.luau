local luau = require("@std/luau")

type node = luau.AstNode

export type replacement = string | node
export type replacements = { [node]: replacement, print: (self: replacements) -> string, __root: node }

return {}
