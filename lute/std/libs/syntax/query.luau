--!strict
-- @std/syntax/query
-- Provides utility functions for querying Luau AST nodes

local luau = require("@std/luau")
local visitor = require("./visitor")

local query = {}

--- Selects a list of expressions from the provided block that match the provided predicate.
--- Useful for defining declarative-based programs, where the matched nodes are mutated for the migration
function query.selectif<T>(block: luau.AstStatBlock, predicate: (luau.AstExpr) -> T?): { T }
	local nodes = {}
	local finder = visitor.createvisitor()

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
