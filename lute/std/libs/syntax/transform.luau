local query = require("@std/syntax/query")
local printer = require("@std/syntax/printer")
local types = require("@std/syntax/types")
local tableext = require("@std/tableext")
export type query<T> = query.query<T>
type node = types.AstNode
type ParseResult = types.ParseResult

local transform = {}
transform.__index = transform

export type TransformData = {
	replacements: types.replacements,
	__parseresult: types.ParseResult,
}

export type transform = typeof(setmetatable({} :: TransformData, transform))

-- transform is entry point for a codemod; exposes base tools you'll need

function transform.new(parseresult: types.ParseResult)
	local self = {
		replacements = {} :: types.replacements,
		__parseresult = parseresult,
	}

	return setmetatable(self, transform)
end

-- how do we enforce that this is always called on desc of our root?
function transform.findallfromroot<T>(self: transform, ast: node, fn: (node) -> T?): query<T>
	local q = query.findallfromroot(ast, fn)
	local t = self
	q.replace = function<V>(self: query<V>, repl: (V) -> types.replacement?)
		local replacements = query.replace(self, repl)
		tableext.combine(t.replacements, replacements)
		return replacements
	end
	return q
end

transform.query = transform.findallfromroot

function transform.transform(self: transform): string
	return printer.printfile(self.__parseresult :: any, self.replacements)
end

return table.freeze(transform)

--[[

example usage:

local t = transform.new(block)

t:findallfromroot()

]]
