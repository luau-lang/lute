--!strict
-- @std/syntax/query
-- Provides utility functions for querying Luau AST nodes

local types = require("./types")
local visitor = require("./visitor")

local query = {}

--- Selects a list of expressions from the provided block that match the provided predicate.
--- Useful for defining declarative-based programs, where the matched nodes are mutated for the migration
function query.selectif<T>(block: types.AstStatBlock, predicate: (types.AstExpr) -> T?): { T }
	local nodes = {}
	local finder = visitor.create()

	finder.visitExpression = function(node)
		local result = predicate(node)
		if result then
			table.insert(nodes, result)
		end

		return true
	end

	visitor.visitblock(block, finder)

	return nodes
end

return table.freeze(query)
