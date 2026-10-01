--!nonstrict
--[[
	luauparser — a Luau parser written in pure Luau.

	A dependency-free alternative to the native `@lute/syntax` AST/CST APIs.
	Parses Luau source text into a concrete syntax tree (CST) that is identical
	to the one produced by Lute's native parser, so tooling (linters, formatters,
	codemods) can be written against it without exposing any native AST APIs.

	Quick start:

		local luau = require("./tools/luauparser") -- path to this folder

		local result = luau.parse("local x = 1 + 2")
		print(result.root.statements[1].tag) --> "local"

		-- Find every binary expression in a file:
		for _, node in luau.findAll(result.root, luau.is("expr", "binary")) do
			print(node.operator.text)
		end

	The CST shape matches `@lute/syntax/cst`: every node carries a `location`
	span and a `kind` (`"stat" | "expr" | "type" | "typepack" | "token" | ...`)
	plus a `tag` discriminator. See `README.md` for the full tour.
]]

local parser = require("@self/src/parser")

local luauparser = {}

--- Parses `source` as a complete Luau chunk.
--- Returns `{ root, eof, lines, lineOffsets }` where `root` is a block CST node.
function luauparser.parse(source: string)
	return parser.parse(source)
end

--- Parses `source` as a single Luau expression and returns the CST node.
function luauparser.parseExpr(source: string)
	return parser.parseExpr(source)
end

--- Parses `source` and returns just the root block node (the common case).
function luauparser.parseBlock(source: string)
	return parser.parse(source).root
end

-- A CST node is any table carrying a `kind` field (statements, expressions,
-- types, type packs, locals, attributes, and tokens).
local function isNode(value: any): boolean
	return type(value) == "table" and value.kind ~= nil
end

--- Depth-first walk over every CST node reachable from `root`, calling
--- `visit(node)` once per node. Returning `false` from `visit` skips that
--- node's children. Shared nodes (e.g. a local's binding) are visited once.
function luauparser.walk(root: any, visit: (node: any) -> boolean?)
	local seen = {}
	local function recurse(value: any)
		if type(value) ~= "table" then
			return
		end
		if isNode(value) then
			if seen[value] then
				return
			end
			seen[value] = true
			if visit(value) == false then
				return
			end
		end
		for _, child in value do
			recurse(child)
		end
	end
	recurse(root)
end

--- Collects every node for which `predicate(node)` is truthy, in document order.
function luauparser.findAll(root: any, predicate: (node: any) -> boolean?): { any }
	local matches = {}
	luauparser.walk(root, function(node)
		if predicate(node) then
			table.insert(matches, node)
		end
		return nil
	end)
	return matches
end

--- Returns the first node matching `predicate`, or `nil`.
function luauparser.find(root: any, predicate: (node: any) -> boolean?): any?
	local found: any = nil
	luauparser.walk(root, function(node)
		if found == nil and predicate(node) then
			found = node
		end
		return nil
	end)
	return found
end

--- Builds a predicate matching nodes by `kind` and (optionally) `tag`.
--- e.g. `luau.is("expr", "binary")`, `luau.is("stat")`.
function luauparser.is(kind: string, tag: string?): (node: any) -> boolean
	return function(node: any): boolean
		return node.kind == kind and (tag == nil or node.tag == tag)
	end
end

return table.freeze(luauparser)
