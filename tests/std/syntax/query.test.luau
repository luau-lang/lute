local syntax = require("@std/syntax")
local query = require("@std/syntax/query")
local test = require("@std/test")
local utils = require("@std/syntax/utils")

test.suite("CstQuery", function(suite)
	suite:case("filter", function(assert)
		local testQuery = query.findAllFromRoot(syntax.parse("local _ = {0, 1, 2, 3, 4}"), utils.isExprConstantNumber)

		local filteredQuery = testQuery:filter(function(n)
			return n.value > 2
		end)

		assert.eq(#filteredQuery.nodes, 2)
		assert.eq(filteredQuery.nodes[1].value, 3)
		assert.eq(filteredQuery.nodes[2].value, 4)
		assert.eq(filteredQuery, testQuery) -- ensure the original query is mutated
	end)

	suite:case("replace", function(assert)
		local testQuery = query.findAllFromRoot(syntax.parse("local _ = {0, 1, 2, 3, 4}"), utils.isExprConstantNumber)

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
		local testQuery = query.findAllFromRoot(syntax.parse("local _ = {0, 1, 2, 3, 4}"), utils.isExprConstantNumber)

		local mappedQuery = query.map(testQuery, function(n: syntax.CstExprConstantNumber): number?
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
		local testQuery = query.findAllFromRoot(syntax.parse("local _ = {0, 1, 2}"), utils.isExprConstantNumber)

		local sum = 0
		testQuery:forEach(function(n: syntax.CstExprConstantNumber)
			sum = sum + n.value
		end)

		assert.eq(sum, 3) -- 0 + 1 + 2 = 3
	end)

	suite:case("findallNums", function(assert)
		local cst = syntax.parse("print(1 + 2)")
		local queryResult: query.Query<syntax.CstExprConstantNumber> = query.findAllFromRoot(
			cst,
			function(n: syntax.CstNode): syntax.CstExprConstantNumber?
				if n.kind == "expr" and n.tag == "number" then
					return n
				end
				return nil
			end
		)

		assert.eq(#queryResult.nodes, 2)
		local num: syntax.CstExpr = queryResult.nodes[1]
		assert.eq(num.kind, "expr")
		assert.eq(num.tag, "number")
		assert.eq((num :: syntax.CstExprConstantNumber).value, 1)
		num = queryResult.nodes[2]
		assert.eq(num.kind, "expr")
		assert.eq(num.tag, "number")
		assert.eq((num :: syntax.CstExprConstantNumber).value, 2)
	end)

	suite:case("findallUtils", function(assert)
		local cst = syntax.parse("print(1 + 2)")
		local queryResult: query.Query<syntax.CstExprConstantNumber> =
			query.findAllFromRoot(cst, utils.isExprConstantNumber)

		assert.eq(#queryResult.nodes, 2)
		local num: syntax.CstExpr = queryResult.nodes[1]
		assert.eq(num.kind, "expr")
		assert.eq(num.tag, "number")
		assert.eq((num :: syntax.CstExprConstantNumber).value, 1)
		num = queryResult.nodes[2]
		assert.eq(num.kind, "expr")
		assert.eq(num.tag, "number")
		assert.eq((num :: syntax.CstExprConstantNumber).value, 2)
	end)

	suite:case("findallTokens", function(assert)
		local cst = syntax.parse("local x = 1 or nil")
		-- verify that query doesn't doubly count tokens
		local queryResult = query.findAllFromRoot(cst, utils.isToken)
		assert.eq(#queryResult.nodes, 6)
		queryResult:forEach(function(node)
			assert.eq(node.kind, "token")
		end)
		local constNums = query.findAllFromRoot(cst, utils.isExprConstantNumber)
		assert.eq(#constNums.nodes, 1)
		local constNils = query.findAllFromRoot(cst, utils.isExprConstantNil)
		assert.eq(#constNils.nodes, 1)
		local tokens = query.findAllFromRoot(cst, utils.isToken)
		assert.eq(#tokens.nodes, 6)
	end)

	suite:case("findall", function(assert)
		-- Test selecting from a query of binary expressions to find their operands
		local cst = syntax.parse("local x = 1 + 2")
		local nums = query.findAllFromRoot(cst, utils.isExprBinary):findAll(utils.isExprConstantNumber)

		assert.eq(#nums.nodes, 2)
		assert.eq(nums.nodes[1].value, 1)
		assert.eq(nums.nodes[2].value, 2)
	end)

	suite:case("findall", function(assert)
		-- Test selecting through nested structures
		local cst = syntax.parse("local x = {a = 1 + 2, b = 3 + 4}")
		local tables = query.findAllFromRoot(cst, utils.isExprTable)

		-- Select all binary expressions within the table
		local binaryExprs = tables:findAll(utils.isExprBinary)

		assert.eq(#binaryExprs.nodes, 2)

		-- Now select all numbers from those binary expressions
		local numbers = binaryExprs:findAll(utils.isExprConstantNumber)

		assert.eq(#numbers.nodes, 4)
		assert.eq(numbers.nodes[1].value, 1)
		assert.eq(numbers.nodes[2].value, 2)
		assert.eq(numbers.nodes[3].value, 3)
		assert.eq(numbers.nodes[4].value, 4)
	end)

	suite:case("flatmap", function(assert)
		-- Test flatmap to collect multiple items from each node
		local cst = syntax.parse("local x = 1 + 2; local y = 3 + 4")
		local locals = query.findAllFromRoot(cst, utils.isStatLocal):flatMap(function(l)
			local values = {}
			for _, v in l.values do
				table.insert(values, v)
			end
			return values
		end)

		assert.eq(#locals.nodes, 2) -- Two binary expressions
		assert.eq(locals.nodes[1].kind, "expr")
		assert.eq(locals.nodes[1].tag, "binary")
		assert.eq(locals.nodes[2].kind, "expr")
		assert.eq(locals.nodes[2].tag, "binary")
	end)

	suite:case("flatmapEmpty", function(assert)
		-- Test flatmap with some nodes returning empty arrays
		local cst = syntax.parse("local x; local y = 1; local z")
		local locals = query.findAllFromRoot(cst, utils.isStatLocal):flatMap(function(l)
			local values = {}
			for _, v in l.values do
				table.insert(values, v)
			end
			return values
		end)

		assert.eq(#locals.nodes, 1) -- Only 'local y = 1' has a value
		assert.eq(locals.nodes[1].kind, "expr")
		assert.eq(locals.nodes[1].tag, "number")
		assert.eq((locals.nodes[1] :: syntax.CstExprConstantNumber).value, 1)
	end)

	suite:case("flatmapMultiple", function(assert)
		-- Test flatmap with nodes that return multiple items
		local cst = syntax.parse("local a, b = 1, 2; local c, d = 3, 4, 5")
		local locals = query.findAllFromRoot(cst, utils.isStatLocal):flatMap(function(l: syntax.CstStatLocal)
			local vars = {}
			for _, v in l.variables do
				table.insert(vars, v)
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
		local cst = syntax.parse("local _ = {0, 1, 2, 3, 4}")
		local nums = query.findAllFromRoot(cst, utils.isExprConstantNumber)

		local doubled = nums:mapToArray(function(n: syntax.CstExprConstantNumber): number
			return n.value * 2
		end)

		assert.eq(#doubled, 5)
		assert.eq(doubled[1], 0)
		assert.eq(doubled[2], 2)
		assert.eq(doubled[3], 4)
		assert.eq(doubled[4], 6)
		assert.eq(doubled[5], 8)
	end)

	suite:case("maptoarrayWithNil", function(assert)
		-- Test maptoarray filtering out nil values
		local cst = syntax.parse("local _ = {0, 1, 2, 3, 4}")
		local nums = query.findAllFromRoot(cst, utils.isExprConstantNumber)

		local evenOnly = nums:mapToArray(function(n: syntax.CstExprConstantNumber): number?
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

	suite:case("queryExprGroup", function(assert)
		local cst = syntax.parse("local x = (1)")

		local exprGroups = query.findAllFromRoot(cst, utils.isExprGroup)
		assert.eq(#exprGroups.nodes, 1)
	end)

	suite:case("queryExprConstantNil", function(assert)
		local cst = syntax.parse("local x = nil")

		local exprNils = query.findAllFromRoot(cst, utils.isExprConstantNil)
		assert.eq(#exprNils.nodes, 1)
	end)

	suite:case("queryExprConstantBool", function(assert)
		local cst = syntax.parse("local x = true")

		local exprBools = query.findAllFromRoot(cst, utils.isExprConstantBool)
		assert.eq(#exprBools.nodes, 1)
	end)

	suite:case("queryExprConstantNumber", function(assert)
		local cst = syntax.parse("local x = 1")

		local exprNumbers = query.findAllFromRoot(cst, utils.isExprConstantNumber)
		assert.eq(#exprNumbers.nodes, 1)
	end)

	suite:case("queryExprConstantInteger", function(assert)
		local cst = syntax.parse("local x = 42i")

		local exprIntegers = query.findAllFromRoot(cst, utils.isExprConstantInteger)
		assert.eq(#exprIntegers.nodes, 1)
	end)

	suite:case("queryExprConstantString", function(assert)
		local cst = syntax.parse('local x = "hello"')

		local exprStrings = query.findAllFromRoot(cst, utils.isExprConstantString)
		assert.eq(#exprStrings.nodes, 1)
	end)

	suite:case("queryExprLocal", function(assert)
		local cst = syntax.parse([[
local x = 1
local y = x
]])

		local exprLocals = query.findAllFromRoot(cst, utils.isExprLocal)
		assert.eq(#exprLocals.nodes, 1)
	end)

	suite:case("queryExprGlobal", function(assert)
		local cst = syntax.parse("local x = foo")

		local exprGlobals = query.findAllFromRoot(cst, utils.isExprGlobal)
		assert.eq(#exprGlobals.nodes, 1)
	end)

	suite:case("queryExprVarargs", function(assert)
		local cst = syntax.parse("local x = ...")

		local exprVarargs = query.findAllFromRoot(cst, utils.isExprVarargs)
		assert.eq(#exprVarargs.nodes, 1)
	end)

	suite:case("queryExprCall", function(assert)
		local cst = syntax.parse("foo()")

		local exprCalls = query.findAllFromRoot(cst, utils.isExprCall)
		assert.eq(#exprCalls.nodes, 1)
	end)

	suite:case("queryExprInstantiate", function(assert)
		local cst = syntax.parse("foo<<number>>()")

		-- no utils predicate exists for instantiation, so match on the tag directly
		local exprInstantiates = query.findAllFromRoot(cst, utils.isExprInstantiate)
		assert.eq(#exprInstantiates.nodes, 1)
	end)

	suite:case("queryExprIndexName", function(assert)
		local cst = syntax.parse("local x = a.b")

		local exprIndexNames = query.findAllFromRoot(cst, utils.isExprIndexName)
		assert.eq(#exprIndexNames.nodes, 1)
	end)

	suite:case("queryExprIndexExpr", function(assert)
		local cst = syntax.parse("local x = a[b]")

		local exprIndexExprs = query.findAllFromRoot(cst, utils.isExprIndexExpr)
		assert.eq(#exprIndexExprs.nodes, 1)
	end)

	suite:case("queryExprFunction", function(assert)
		local cst = syntax.parse([[
local f = function() end
function g() end
]])

		local exprFunctions = query.findAllFromRoot(cst, utils.isExprFunction)
		assert.eq(#exprFunctions.nodes, 2)
	end)

	suite:case("queryExprTable", function(assert)
		local cst = syntax.parse("local x = {}")

		local exprTables = query.findAllFromRoot(cst, utils.isExprTable)
		assert.eq(#exprTables.nodes, 1)
	end)

	suite:case("queryExprUnary", function(assert)
		local cst = syntax.parse("local x = -y")

		local exprUnaries = query.findAllFromRoot(cst, utils.isExprUnary)
		assert.eq(#exprUnaries.nodes, 1)
	end)

	suite:case("queryExprBinary", function(assert)
		local cst = syntax.parse("local x = 1 + 2")

		local exprBinaries = query.findAllFromRoot(cst, utils.isExprBinary)
		assert.eq(#exprBinaries.nodes, 1)
	end)

	suite:case("queryExprInterpString", function(assert)
		local cst = syntax.parse("local x = `hello {y}`")

		local exprInterpStrings = query.findAllFromRoot(cst, utils.isExprInterpString)
		assert.eq(#exprInterpStrings.nodes, 1)
	end)

	suite:case("queryExprTypeAssertion", function(assert)
		local cst = syntax.parse("local x = y :: number")

		local exprTypeAssertions = query.findAllFromRoot(cst, utils.isExprTypeAssertion)
		assert.eq(#exprTypeAssertions.nodes, 1)
	end)

	suite:case("queryExprIfElse", function(assert)
		local cst = syntax.parse("local x = if a then b else c")

		local exprIfElses = query.findAllFromRoot(cst, utils.isExprIfElse)
		assert.eq(#exprIfElses.nodes, 1)
	end)

	suite:case("queryStatBlock", function(assert)
		local cst = syntax.parse([[
do
	local x = 1
end
]])

		-- the root block plus the do-block's body
		local statBlocks = query.findAllFromRoot(cst, utils.isStatBlock)
		assert.eq(#statBlocks.nodes, 2)
	end)

	suite:case("queryStatDo", function(assert)
		local cst = syntax.parse([[
do
	local x = 1
	local y = 2
end
]])

		local statDos = query.findAllFromRoot(cst, utils.isStatDo)
		assert.eq(#statDos.nodes, 1)
	end)

	suite:case("queryStatIf", function(assert)
		local cst = syntax.parse([[
if x then
end
]])

		local statIfs = query.findAllFromRoot(cst, utils.isStatIf)
		assert.eq(#statIfs.nodes, 1)
	end)

	suite:case("queryStatWhile", function(assert)
		local cst = syntax.parse([[
while x do
end
]])

		local statWhiles = query.findAllFromRoot(cst, utils.isStatWhile)
		assert.eq(#statWhiles.nodes, 1)
	end)

	suite:case("queryStatRepeat", function(assert)
		local cst = syntax.parse([[
repeat
until x
]])

		local statRepeats = query.findAllFromRoot(cst, utils.isStatRepeat)
		assert.eq(#statRepeats.nodes, 1)
	end)

	suite:case("queryStatBreak", function(assert)
		local cst = syntax.parse([[
while true do
	break
end
]])

		local statBreaks = query.findAllFromRoot(cst, utils.isStatBreak)
		assert.eq(#statBreaks.nodes, 1)
	end)

	suite:case("queryStatContinue", function(assert)
		local cst = syntax.parse([[
while true do
	continue
end
]])

		local statContinues = query.findAllFromRoot(cst, utils.isStatContinue)
		assert.eq(#statContinues.nodes, 1)
	end)

	suite:case("queryStatReturn", function(assert)
		local cst = syntax.parse("return")

		local statReturns = query.findAllFromRoot(cst, utils.isStatReturn)
		assert.eq(#statReturns.nodes, 1)
	end)

	suite:case("queryStatExpr", function(assert)
		local cst = syntax.parse("foo()")

		local statExprs = query.findAllFromRoot(cst, utils.isStatExpr)
		assert.eq(#statExprs.nodes, 1)
	end)

	suite:case("queryStatLocal", function(assert)
		local cst = syntax.parse([[
local x = 1
local y = 2
]])

		local statLocals = query.findAllFromRoot(cst, utils.isStatLocal)
		assert.eq(#statLocals.nodes, 2)
	end)

	suite:case("queryStatConst", function(assert)
		local cst = syntax.parse([[
const x = 1
const y = 2
]])

		local statConsts = query.findAllFromRoot(cst, utils.isStatConst)
		assert.eq(#statConsts.nodes, 2)
	end)

	suite:case("queryStatFor", function(assert)
		local cst = syntax.parse([[
for i = 1, 10 do
end
]])

		local statFors = query.findAllFromRoot(cst, utils.isStatFor)
		assert.eq(#statFors.nodes, 1)
	end)

	suite:case("queryStatForIn", function(assert)
		local cst = syntax.parse([[
for i, v in pairs(t) do
end
]])

		local statForIns = query.findAllFromRoot(cst, utils.isStatForIn)
		assert.eq(#statForIns.nodes, 1)
	end)

	suite:case("queryStatAssign", function(assert)
		local cst = syntax.parse("x = 1")

		local statAssigns = query.findAllFromRoot(cst, utils.isStatAssign)
		assert.eq(#statAssigns.nodes, 1)
	end)

	suite:case("queryStatCompoundAssign", function(assert)
		local cst = syntax.parse("x += 1")

		local statCompoundAssigns = query.findAllFromRoot(cst, utils.isStatCompoundAssign)
		assert.eq(#statCompoundAssigns.nodes, 1)
	end)

	suite:case("queryStatFunction", function(assert)
		local cst = syntax.parse("function foo() end")

		local statFunctions = query.findAllFromRoot(cst, utils.isStatFunction)
		assert.eq(#statFunctions.nodes, 1)
	end)

	suite:case("queryStatLocalFunction", function(assert)
		local cst = syntax.parse("local function foo() end")

		local statLocalFunctions = query.findAllFromRoot(cst, utils.isStatLocalFunction)
		assert.eq(#statLocalFunctions.nodes, 1)
	end)

	suite:case("queryStatTypeAlias", function(assert)
		local cst = syntax.parse("type X = number")

		local statTypeAliases = query.findAllFromRoot(cst, utils.isStatTypeAlias)
		assert.eq(#statTypeAliases.nodes, 1)
	end)

	suite:case("queryStatTypeFunction", function(assert)
		local cst = syntax.parse("type function foo() return types.number end")

		local statTypeFunctions = query.findAllFromRoot(cst, utils.isStatTypeFunction)
		assert.eq(#statTypeFunctions.nodes, 1)
	end)

	suite:case("queryTypeReference", function(assert)
		local cst = syntax.parse("type T = number")

		local typeReferences = query.findAllFromRoot(cst, utils.isTypeReference)
		assert.eq(#typeReferences.nodes, 1)
	end)

	suite:case("queryTypeSingletonBool", function(assert)
		local cst = syntax.parse("type T = true")

		local typeSingletonBools = query.findAllFromRoot(cst, utils.isTypeSingletonBool)
		assert.eq(#typeSingletonBools.nodes, 1)
	end)

	suite:case("queryTypeSingletonString", function(assert)
		local cst = syntax.parse('type T = "hello"')

		local typeSingletonStrings = query.findAllFromRoot(cst, utils.isTypeSingletonString)
		assert.eq(#typeSingletonStrings.nodes, 1)
	end)

	suite:case("queryTypeTypeof", function(assert)
		local cst = syntax.parse("type T = typeof(x)")

		local typeTypeofs = query.findAllFromRoot(cst, utils.isTypeTypeof)
		assert.eq(#typeTypeofs.nodes, 1)
	end)

	suite:case("queryTypeGroup", function(assert)
		local cst = syntax.parse("type T = (number)")

		local typeGroups = query.findAllFromRoot(cst, utils.isTypeGroup)
		assert.eq(#typeGroups.nodes, 1)
	end)

	suite:case("queryTypeUnion", function(assert)
		local cst = syntax.parse("type T = number | string")

		local typeUnions = query.findAllFromRoot(cst, utils.isTypeUnion)
		assert.eq(#typeUnions.nodes, 1)
	end)

	suite:case("queryTypeIntersection", function(assert)
		local cst = syntax.parse("type T = A & B")

		local typeIntersections = query.findAllFromRoot(cst, utils.isTypeIntersection)
		assert.eq(#typeIntersections.nodes, 1)
	end)

	suite:case("queryTypeOptional", function(assert)
		local cst = syntax.parse("type T = number?")

		local typeOptionals = query.findAllFromRoot(cst, utils.isTypeOptional)
		assert.eq(#typeOptionals.nodes, 1)
	end)

	suite:case("queryTypeArray", function(assert)
		local cst = syntax.parse("type T = { number }")

		local typeArrays = query.findAllFromRoot(cst, utils.isTypeArray)
		assert.eq(#typeArrays.nodes, 1)
	end)

	suite:case("queryTypeTable", function(assert)
		local cst = syntax.parse("type T = { x: number }")

		local typeTables = query.findAllFromRoot(cst, utils.isTypeTable)
		assert.eq(#typeTables.nodes, 1)
	end)

	suite:case("queryTypeFunction", function(assert)
		local cst = syntax.parse("type T = () -> ()")

		local typeFunctions = query.findAllFromRoot(cst, utils.isTypeFunction)
		assert.eq(#typeFunctions.nodes, 1)
	end)
end)
