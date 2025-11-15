local query = require("@std/syntax/query")
local types = require("@std/syntax/types")
local tableext = require("@std/tableext")
type query<T> = query.query<T>
type node = types.AstNode

local transform = {}
transform.__index = transform

export type TransformData = {
	replacements: types.replacements,
}

export type transform = typeof(setmetatable({} :: TransformData, transform))

function transform.new()
	local self = {
		replacements = {} :: types.replacements,
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

return table.freeze(transform)

--[[

example usage:

local t = transform.new(block)

t:selectFromRoot()

]]
