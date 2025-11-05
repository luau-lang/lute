local test = require("@std/test")
local query = require("@std/syntax/query")
local luau = require("@std/luau")
local utils = require("@std/syntax/utils")

local function mockQuery<T>(nodes: { T }): query.query<T>
	return {
		nodes = nodes,
		filter = query.filter,
		replace = query.replace,
		map = query.map, -- LUAUFIX: should this subtype?
	}
end

-- Helper function to create mock number expressions
local function createNumberExpr(value: number): luau.AstExprConstantNumber
	return {
		tag = "number",
		kind = "expr",
		value = value,
		text = tostring(value),
		position = { line = 1, column = 1 },
		leadingtrivia = {},
		trailingtrivia = {},
	} :: any
end

test.suite("AST Query", function(suite)
	suite:case("filter", function(assert)
		local testQuery = mockQuery({
			createNumberExpr(-2),
			createNumberExpr(-1),
			createNumberExpr(0),
			createNumberExpr(1),
			createNumberExpr(2),
		})

		local filteredQuery = testQuery:filter(function(n)
			return n.value > 0
		end)

		assert.eq(#filteredQuery.nodes, 2)
		assert.eq(filteredQuery.nodes[1].value, 1)
		assert.eq(filteredQuery.nodes[2].value, 2)
		assert.eq(filteredQuery, testQuery) -- ensure the original query is mutated
	end)

	suite:case("replace", function(assert)
		local testQuery = mockQuery({
			createNumberExpr(-2),
			createNumberExpr(-1),
			createNumberExpr(0),
			createNumberExpr(1),
			createNumberExpr(2),
		})

		local replacements = testQuery:replace(function(n): string?
			if n.value > 0 then
				return "positive_" .. tostring(n.value)
			end
			return nil -- return nil for non-positive numbers
		end)

		-- Should only have replacements for positive numbers
		assert.eq(replacements[testQuery.nodes[4] :: luau.AstNode], "positive_1") -- LUAUFIX CLI-178250: shouldn't need to cast
		assert.eq(replacements[testQuery.nodes[5] :: luau.AstNode], "positive_2") -- LUAUFIX CLI-178250: shouldn't need to cast

		-- Non-positive numbers should not have replacements (nil values)
		assert.eq(replacements[testQuery.nodes[1] :: luau.AstNode], nil) -- LUAUFIX CLI-178250: shouldn't need to cast
		assert.eq(replacements[testQuery.nodes[2] :: luau.AstNode], nil) -- LUAUFIX CLI-178250: shouldn't need to cast
		assert.eq(replacements[testQuery.nodes[3] :: luau.AstNode], nil) -- LUAUFIX CLI-178250: shouldn't need to cast

		-- Verify the replacement table only contains the expected entries
		local count = 0
		for _, _ in pairs(replacements) do
			count = count + 1
		end
		assert.eq(count, 2) -- Only 2 non-nil replacements
	end)

	suite:case("map", function(assert)
		local testQuery = mockQuery({
			createNumberExpr(-2),
			createNumberExpr(-1),
			createNumberExpr(0),
			createNumberExpr(1),
			createNumberExpr(2),
		})

		local mappedQuery = query.map(testQuery, function(n: luau.AstExprConstantNumber): number?
			if n.value % 2 == 0 then
				return n.value * 10
			end
			return nil -- return nil for odd numbers
		end)

		assert.eq(#mappedQuery.nodes, 3)
		assert.eq(mappedQuery.nodes[1], -20)
		assert.eq(mappedQuery.nodes[2], 0)
		assert.eq(mappedQuery.nodes[3], 20)
	end)

	suite:case("select_nums", function(assert)
		local ast = luau.parse("print(1 + 2)")
		local queryResult: query.query<luau.AstExprConstantNumber> = query.select(
			ast.root :: luau.AstNode,
			function(n: luau.AstNode): luau.AstExprConstantNumber?
				if n.kind == "expr" and n.tag == "number" then
					return n
				end
				return nil
			end
		)

		assert.eq(#queryResult.nodes, 2)
		local num: luau.AstExpr = queryResult.nodes[1]
		assert.eq(num.kind, "expr")
		assert.eq(num.tag, "number")
		assert.eq((num :: luau.AstExprConstantNumber).value, 1)
		num = queryResult.nodes[2]
		assert.eq(num.kind, "expr")
		assert.eq(num.tag, "number")
		assert.eq((num :: luau.AstExprConstantNumber).value, 2)
	end)

	suite:case("select_array", function(assert)
		local ast = luau.parse("print(1 + 2)")
		local queryResult: query.query<luau.AstExpr> = query.select(
			ast.root :: luau.AstNode,
			function(n: luau.AstNode): { luau.AstExpr }?
				if n.kind == "expr" and n.tag == "binary" then
					return { n.lhsoperand, n.rhsoperand }
				end
				return nil
			end
		)

		assert.eq(#queryResult.nodes, 2)
		local num: luau.AstExpr = queryResult.nodes[1]
		assert.eq(num.kind, "expr")
		assert.eq(num.tag, "number")
		assert.eq((num :: luau.AstExprConstantNumber).value, 1)
		num = queryResult.nodes[2]
		assert.eq(num.kind, "expr")
		assert.eq(num.tag, "number")
		assert.eq((num :: luau.AstExprConstantNumber).value, 2)
	end)

	suite:case("select_utils", function(assert)
		local ast = luau.parse("print(1 + 2)")
		local queryResult: query.query<luau.AstExprConstantNumber> =
			query.select(ast.root :: luau.AstNode, utils.isExprConstantNumber)

		assert.eq(#queryResult.nodes, 2)
		local num: luau.AstExpr = queryResult.nodes[1]
		assert.eq(num.kind, "expr")
		assert.eq(num.tag, "number")
		assert.eq((num :: luau.AstExprConstantNumber).value, 1)
		num = queryResult.nodes[2]
		assert.eq(num.kind, "expr")
		assert.eq(num.tag, "number")
		assert.eq((num :: luau.AstExprConstantNumber).value, 2)
	end)
end)

test.run()
