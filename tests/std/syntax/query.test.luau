local syntax = require("@std/syntax")
local query = require("@std/syntax/query")
local test = require("@std/test")
local utils = require("@std/syntax/utils")

test.suite("AST Query", function(suite)
	suite:case("filter", function(assert)
		local testQuery = query.findallfromroot(syntax.parse("local _ = {0, 1, 2, 3, 4}"), utils.isExprConstantNumber) -- LUAUFIX: Complains that AstStatBlock doesn't have location? field

		local filteredQuery = testQuery:filter(function(n)
			return n.value > 2
		end)

		assert.eq(#filteredQuery.nodes, 2)
		assert.eq(filteredQuery.nodes[1].value, 3)
		assert.eq(filteredQuery.nodes[2].value, 4)
		assert.eq(filteredQuery, testQuery) -- ensure the original query is mutated
	end)

	suite:case("replace", function(assert)
		local testQuery = query.findallfromroot(syntax.parse("local _ = {0, 1, 2, 3, 4}"), utils.isExprConstantNumber) -- LUAUFIX: Complains that AstStatBlock doesn't have location? field

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
		assert.eq(count, 4) -- 4 non-nil replacements
	end)

	suite:case("map", function(assert)
		local testQuery = query.findallfromroot(syntax.parse("local _ = {0, 1, 2, 3, 4}"), utils.isExprConstantNumber) -- LUAUFIX: Complains that AstStatBlock doesn't have location? field

		local mappedQuery = query.map(testQuery, function(n: syntax.AstExprConstantNumber): number?
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

	suite:case("foreach", function(assert)
		local testQuery = query.findallfromroot(syntax.parse("local _ = {0, 1, 2}"), utils.isExprConstantNumber) -- LUAUFIX: Complains that AstStatBlock doesn't have location? field

		local sum = 0
		testQuery:foreach(function(n: syntax.AstExprConstantNumber)
			sum = sum + n.value
		end)

		assert.eq(sum, 3) -- 0 + 1 + 2 = 3
	end)

	suite:case("findall_nums", function(assert)
		local ast = syntax.parse("print(1 + 2)")
		local queryResult: query.query<syntax.AstExprConstantNumber> = query.findallfromroot(
			ast, -- LUAUFIX: Complains that AstStatBlock doesn't have location? field
			function(n: syntax.AstNode): syntax.AstExprConstantNumber?
				if n.kind == "expr" and n.tag == "number" then
					return n
				end
				return nil
			end
		)

		assert.eq(#queryResult.nodes, 2)
		local num: syntax.AstExpr = queryResult.nodes[1]
		assert.eq(num.kind, "expr")
		assert.eq(num.tag, "number")
		assert.eq((num :: syntax.AstExprConstantNumber).value, 1)
		num = queryResult.nodes[2]
		assert.eq(num.kind, "expr")
		assert.eq(num.tag, "number")
		assert.eq((num :: syntax.AstExprConstantNumber).value, 2)
	end)

	suite:case("findall_utils", function(assert)
		local ast = syntax.parse("print(1 + 2)")
		local queryResult: query.query<syntax.AstExprConstantNumber> =
			query.findallfromroot(ast, utils.isExprConstantNumber) -- LUAUFIX: Complains that AstStatBlock doesn't have location? field

		assert.eq(#queryResult.nodes, 2)
		local num: syntax.AstExpr = queryResult.nodes[1]
		assert.eq(num.kind, "expr")
		assert.eq(num.tag, "number")
		assert.eq((num :: syntax.AstExprConstantNumber).value, 1)
		num = queryResult.nodes[2]
		assert.eq(num.kind, "expr")
		assert.eq(num.tag, "number")
		assert.eq((num :: syntax.AstExprConstantNumber).value, 2)
	end)

	suite:case("findall_tokens", function(assert)
		local ast = syntax.parse("local x = 1 or nil")
		-- verify that query doesn't doubly count tokens
		local queryResult = query.findallfromroot(ast, utils.isToken)
		assert.eq(#queryResult.nodes, 6)
		queryResult:foreach(function(node)
			assert.eq(node.istoken, true)
		end)
		local constNums = query.findallfromroot(ast, utils.isExprConstantNumber)
		assert.eq(#constNums.nodes, 1)
		local constNils = query.findallfromroot(ast, utils.isExprConstantNil)
		assert.eq(#constNils.nodes, 1)
		local baseTokens = query.findallfromroot(ast, utils.isBaseToken)
		assert.eq(#baseTokens.nodes, 4)
	end)

	suite:case("findall", function(assert)
		-- Test selecting from a query of binary expressions to find their operands
		local ast = syntax.parse("local x = 1 + 2")
		local nums = query.findallfromroot(ast, utils.isExprBinary):findall(utils.isExprConstantNumber)

		assert.eq(#nums.nodes, 2)
		assert.eq(nums.nodes[1].value, 1)
		assert.eq(nums.nodes[2].value, 2)
	end)

	suite:case("findall", function(assert)
		-- Test selecting through nested structures
		local ast = syntax.parse("local x = {a = 1 + 2, b = 3 + 4}")
		local tables = query.findallfromroot(ast, utils.isExprTable)

		-- Select all binary expressions within the table
		local binaryExprs = tables:findall(utils.isExprBinary)

		assert.eq(#binaryExprs.nodes, 2)

		-- Now select all numbers from those binary expressions
		local numbers = binaryExprs:findall(utils.isExprConstantNumber)

		assert.eq(#numbers.nodes, 4)
		assert.eq(numbers.nodes[1].value, 1)
		assert.eq(numbers.nodes[2].value, 2)
		assert.eq(numbers.nodes[3].value, 3)
		assert.eq(numbers.nodes[4].value, 4)
	end)

	suite:case("flatmap", function(assert)
		-- Test flatmap to collect multiple items from each node
		local ast = syntax.parse("local x = 1 + 2; local y = 3 + 4")
		local locals = query.findallfromroot(ast, utils.isStatLocal):flatmap(function(l)
			local values = {}
			for _, v in l.values do
				table.insert(values, v.node)
			end
			return values
		end)

		assert.eq(#locals.nodes, 2) -- Two binary expressions
		assert.eq(locals.nodes[1].kind, "expr")
		assert.eq(locals.nodes[1].tag, "binary")
		assert.eq(locals.nodes[2].kind, "expr")
		assert.eq(locals.nodes[2].tag, "binary")
	end)

	suite:case("flatmap_empty", function(assert)
		-- Test flatmap with some nodes returning empty arrays
		local ast = syntax.parse("local x; local y = 1; local z")
		local locals = query.findallfromroot(ast, utils.isStatLocal):flatmap(function(l)
			local values = {}
			for _, v in l.values do
				table.insert(values, v.node)
			end
			return values
		end)

		assert.eq(#locals.nodes, 1) -- Only 'local y = 1' has a value
		assert.eq(locals.nodes[1].kind, "expr")
		assert.eq(locals.nodes[1].tag, "number")
		assert.eq((locals.nodes[1] :: syntax.AstExprConstantNumber).value, 1)
	end)

	suite:case("flatmap_multiple", function(assert)
		-- Test flatmap with nodes that return multiple items
		local ast = syntax.parse("local a, b = 1, 2; local c, d = 3, 4, 5")
		local locals = query.findallfromroot(ast, utils.isStatLocal):flatmap(function(l: syntax.AstStatLocal)
			local vars = {}
			for _, v in l.variables do
				table.insert(vars, v.node)
			end
			return vars
		end)

		assert.eq(#locals.nodes, 4) -- a, b, c, d
		assert.eq(locals.nodes[1].name.text, "a")
		assert.eq(locals.nodes[2].name.text, "b")
		assert.eq(locals.nodes[3].name.text, "c")
		assert.eq(locals.nodes[4].name.text, "d")
	end)

	suite:case("maptoarray", function(assert)
		-- Test maptoarray to convert query nodes to a simple array
		local ast = syntax.parse("local _ = {0, 1, 2, 3, 4}")
		local nums = query.findallfromroot(ast, utils.isExprConstantNumber)

		local doubled = nums:maptoarray(function(n: syntax.AstExprConstantNumber): number
			return n.value * 2
		end)

		assert.eq(#doubled, 5)
		assert.eq(doubled[1], 0)
		assert.eq(doubled[2], 2)
		assert.eq(doubled[3], 4)
		assert.eq(doubled[4], 6)
		assert.eq(doubled[5], 8)
	end)

	suite:case("maptoarray_with_nil", function(assert)
		-- Test maptoarray filtering out nil values
		local ast = syntax.parse("local _ = {0, 1, 2, 3, 4}")
		local nums = query.findallfromroot(ast, utils.isExprConstantNumber)

		local evenOnly = nums:maptoarray(function(n: syntax.AstExprConstantNumber): number?
			if n.value % 2 == 0 then
				return n.value
			end
			return nil
		end)

		assert.eq(#evenOnly, 3)
		assert.eq(evenOnly[1], 0)
		assert.eq(evenOnly[2], 2)
		assert.eq(evenOnly[3], 4)
	end)

	suite:case("exists", function(assert)
		local ast = syntax.parse("local x = 1")

		local hasConstantNum = query.findallfromroot(ast, utils.isExprConstantNumber):exists()
		assert.eq(hasConstantNum, true)
		local hasLocal = query.findallfromroot(ast, utils.isStatLocal):exists()
		assert.eq(hasLocal, true)
		local hasFunctionCall = query.findallfromroot(ast, utils.isExprCall):exists()
		assert.eq(hasFunctionCall, false)

		local hasXToken = query.findallfromroot(ast, utils.isToken):exists(function(t)
			return t.text == "x"
		end)
		assert.eq(hasXToken, true)
		local hasYToken = query.findallfromroot(ast, utils.isToken):exists(function(t)
			return t.text == "y"
		end)
		assert.eq(hasYToken, false)
	end)
end)
