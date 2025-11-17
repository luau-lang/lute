local luau = require("@lute/luau")
local query = require("@std/syntax/query")
local printer = require("@std/syntax/printer")
local types = require("@std/syntax/types")
local tableext = require("@std/tableext")
type query<T> = query.query<T>
type node = types.AstNode

local transform = {}
transform.__index = transform

export type TransformData = {
	replacements: types.replacements,
	__root: node,
}

export type transform = typeof(setmetatable({} :: TransformData, transform))

-- transform is entry point for a codemod; exposes base tools you'll need

function transform.new(fileRoot: node)
	local self = {
		replacements = {} :: types.replacements,
		__root = fileRoot,
	}

	return setmetatable(self, transform)
end

-- how do we enforce that this is always called on desc of our root?
function transform.selectFromRoot<T>(self: transform, ast: node, fn: (node) -> T?): query<T>
	local q = query.selectFromRoot(ast, fn)
	local t = self
	q.replace = function<V>(self: query<V>, repl: (V) -> types.replacement?)
		local replacements = query.replace(self, repl)
		tableext.merge(t.replacements, replacements)
		return replacements
	end
	return q
end

function transform.transform(self: transform): string
	return printer.printnode(self.__root :: any, self.replacements)
end

return table.freeze(transform)

--[[

example usage:

local t = transform.new(block)

t:selectFromRoot()

]]
