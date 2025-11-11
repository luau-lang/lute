local luau = require("@std/luau")
local parser = require("@std/syntax/parser")
local query = require("@std/syntax/query")
local test = require("@std/test")
local utils = require("@std/syntax/utils")

test.suite("AST Query", function(suite)
	suite:case("filter", function(assert)
		local testQuery = query.selectFromRoot(parser.parse("local _ = {0, 1, 2, 3, 4}"), utils.isExprConstantNumber) -- LUAUFIX: Complains that AstStatBlock doesn't have location? field

		local filteredQuery = testQuery:filter(function(n)
			return n.value > 2
		end)

		assert.eq(#filteredQuery.nodes, 2)
		assert.eq(filteredQuery.nodes[1].value, 3)
		assert.eq(filteredQuery.nodes[2].value, 4)
		assert.eq(filteredQuery, testQuery) -- ensure the original query is mutated
	end)

	suite:case("replace", function(assert)
		local testQuery = query.selectFromRoot(parser.parse("local _ = {0, 1, 2, 3, 4}"), utils.isExprConstantNumber) -- LUAUFIX: Complains that AstStatBlock doesn't have location? field

		local replacements = testQuery:replace(function(n): string?
			if n.value > 0 then
				return "positive_" .. tostring(n.value)
			end
			return nil -- return nil for non-positive numbers
		end)

		-- Should only have replacements for positive numbers
		assert.eq(replacements[testQuery.nodes[2]], "positive_1") -- LUAUFIX CLI-178250: shouldn't need to cast
		assert.eq(replacements[testQuery.nodes[3]], "positive_2") -- LUAUFIX CLI-178250: shouldn't need to cast
		assert.eq(replacements[testQuery.nodes[4]], "positive_3") -- LUAUFIX CLI-178250: shouldn't need to cast
		assert.eq(replacements[testQuery.nodes[5]], "positive_4") -- LUAUFIX CLI-178250: shouldn't need to cast

		-- Non-positive numbers should not have replacements (nil values)
		assert.eq(replacements[testQuery.nodes[1]], nil) -- LUAUFIX CLI-178250: shouldn't need to cast

		-- Verify the replacement table only contains the expected entries
		local count = 0
		for _, _ in replacements do
			count += 1
		end
		assert.eq(count, 6) -- 4 non-nil replacements + print + __root
	end)

	suite:case("map", function(assert)
		local testQuery = query.selectFromRoot(parser.parse("local _ = {0, 1, 2, 3, 4}"), utils.isExprConstantNumber) -- LUAUFIX: Complains that AstStatBlock doesn't have location? field

		local mappedQuery = query.map(testQuery, function(n: luau.AstExprConstantNumber): number?
			if n.value % 2 == 0 then
				return n.value * 10
			end
			return nil -- return nil for odd numbers
		end)

		assert.eq(#mappedQuery.nodes, 3)
		assert.eq(mappedQuery.nodes[1], 0)
		assert.eq(mappedQuery.nodes[2], 20)
		assert.eq(mappedQuery.nodes[3], 40)
	end)

	suite:case("forEach", function(assert)
		local testQuery = query.selectFromRoot(parser.parse("local _ = {0, 1, 2}"), utils.isExprConstantNumber) -- LUAUFIX: Complains that AstStatBlock doesn't have location? field

		local sum = 0
		testQuery:forEach(function(n: luau.AstExprConstantNumber)
			sum = sum + n.value
		end)

		assert.eq(sum, 3) -- 0 + 1 + 2 = 3
	end)

	suite:case("select_nums", function(assert)
		local ast = luau.parse("print(1 + 2)")
		local queryResult: query.query<luau.AstExprConstantNumber> = query.selectFromRoot(
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

	suite:case("select_utils", function(assert)
		local ast = luau.parse("print(1 + 2)")
		local queryResult: query.query<luau.AstExprConstantNumber> =
			query.selectFromRoot(ast.root :: luau.AstNode, utils.isExprConstantNumber)

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
