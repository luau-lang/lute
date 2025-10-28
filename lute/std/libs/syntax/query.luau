local luau = require("@lute/luau")

local visitor = require("./visitor")

--- Selects a list of expressions from the provided block that match the provided predicate.
--- Useful for defining declarative-based programs, where the matched nodes are mutated for the migration
local function selectif<T>(block: luau.AstStatBlock, predicate: (luau.AstExpr) -> T?): { T }
	local nodes = {}
	local finder = visitor.createVisitor()

	finder.visitExpression = function(node)
		local result = predicate(node)
		if result then
			table.insert(nodes, result)
		end

		return true
	end

	visitor.visitBlock(block, finder)

	return nodes
end

return {
	selectif = selectif,
}
