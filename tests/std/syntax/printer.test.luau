local testtypes = require("@std/test/types")
local printer = require("@std/syntax/printer")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local syntaxTypes = require("@std/syntax/types")
local syntaxUtils = require("@std/syntax/utils")
local test = require("@std/test")

local function checkReplacement(
	source: string,
	expected: string,
	transformFn: (syntaxTypes.AstNode) -> syntaxTypes.replacements?,
	assert: testtypes.asserts
)
	local ast = syntax.parse(source)
	local replacements = transformFn(ast.root)

	local result = printer.printfile(ast, replacements)

	assert.eq(result, expected)
end

test.suite("SyntaxPrinter", function(suite)
	suite:case("stringReplacement", function(assert)
		local source = [[
            local name = "World"
]]

		local expected = "            local name = 1 + 2\n"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isExprConstantString)
				:replace(function(s) -- LUAUFIX: Remove any cast once code too complex no longer emitted
					return if s.token.text == "World" then "1 + 2" else nil
				end)
		end, assert)
	end)

	suite:case("exprReplacement", function(assert)
		local source = [[
            local name = "World"
]]

		local expected = "            local name = 1 + 2\n"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isExprConstantString)
				:replace(function(s) -- LUAUFIX: Remove any cast once code too complex no longer emitted
					return if s.token.text == "World" then syntax.parseexpr("1 + 2") else nil
				end)
		end, assert)
	end)

	suite:case("statReplacement", function(assert)
		local source = [[
            local name = "World"
]]

		local expected = "            local name = 1 + 2\n"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isStatLocal) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function(_)
					return syntax.parseblock("local name = 1 + 2")
				end)
		end, assert)
	end)

	suite:case("typeReplacement", function(assert)
		local source = [[local name: number = "World"]]
		local expected = [[local name: string = "World"]]

		local stat = syntax.parseblock("local x: string")
		local ann = (stat.statements[1] :: syntaxTypes.AstStatLocal).variables[1].node.annotation

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isStatLocal) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:map(function(assign)
					return assign.variables[1].node.annotation
				end)
				:replace(function(_)
					return ann
				end)
		end, assert)
	end)

	suite:case("typePackReplacement", function(assert)
		local source = [[type t = (...number) -> ()]]
		local expected = [[type t = (...number) -> string, ...string)]]

		local stat = syntax.parseblock("type t = () -> (string, ...string)")
		local tp = ((stat.statements[1] :: syntaxTypes.AstStatTypeAlias).type :: syntaxTypes.AstTypeFunction).returntypes

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isStatTypeAlias) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:map(function(ta)
					return if ta.type.tag == "function" then ta.type.returntypes else nil
				end)
				:replace(function(_)
					return tp
				end)
		end, assert)
	end)

	suite:case("exprTableItemReplacement", function(assert)
		local source = "local tbl = { a = 1, }"
		local expected = "local tbl = { b = 2, }"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isExprTable) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:map(function(node)
					return node.entries[1]
				end)
				:replace(function(_)
					return "b = 2,"
				end)
		end, assert)
	end)

	suite:case("exprGroupTrivia", function(assert)
		local source = [[local x =
(1 + 2) -- after]]
		local expected = "local x =\nreplaced -- after"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isExprGroup) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("exprNilTrivia", function(assert)
		local source = [[local x =
nil -- after]]
		local expected = "local x =\nreplaced -- after"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isExprConstantNil) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("exprBoolTrivia", function(assert)
		local source = [[local x =
true -- after]]
		local expected = "local x =\nreplaced -- after"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isExprConstantBool) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("exprNumberTrivia", function(assert)
		local source = [[local x =
235 -- after]]
		local expected = "local x =\nreplaced -- after"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isExprConstantNumber) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("exprLocalTrivia", function(assert)
		local source = [[local y = 3
		local x =
y -- after]]
		local expected = "local y = 3\n\t\tlocal x =\nreplaced -- after"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isExprLocal) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("exprGlobalTrivia", function(assert)
		local source = [[local x =
y -- after]]
		local expected = "local x =\nreplaced -- after"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isExprGlobal) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("exprVarargsTrivia", function(assert)
		local source = [[local x =
... -- after]]
		local expected = "local x =\nreplaced -- after"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isExprVarargs) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("exprCallTrivia", function(assert)
		local source = [[local x =
print() -- after]]
		local expected = "local x =\nreplaced -- after"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isExprCall) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("exprIndexNameTrivia", function(assert)
		local source = [[local x =
hello.world -- after]]
		local expected = "local x =\nreplaced -- after"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isExprIndexName) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("exprIndexExprTrivia", function(assert)
		local source = [[local x =
hello['world'] -- after]]
		local expected = "local x =\nreplaced -- after"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isExprIndexExpr) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("exprFunctionTrivia", function(assert)
		local source = [[local x =
function() return end -- after]]
		local expected = "local x =\nreplaced -- after"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isExprFunction) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("exprTableTrivia", function(assert)
		local source = [[local x =
{} -- after]]
		local expected = "local x =\nreplaced -- after"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isExprTable) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("exprUnaryTrivia", function(assert)
		local source = [[local x =
#t -- after]]
		local expected = "local x =\nreplaced -- after"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isExprUnary) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("exprBinaryTrivia", function(assert)
		local source = [[local x =
3 + 2 -- after]]
		local expected = "local x =\nreplaced -- after"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isExprBinary) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("exprInterpStringTrivia", function(assert)
		local source = [[local x =
`hello {"world"}` -- after]]
		local expected = "local x =\nreplaced -- after"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isExprInterpString) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("exprTypeAssertionTrivia", function(assert)
		local source = [[local x =
y :: number -- after]]
		local expected = "local x =\nreplaced -- after"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isExprTypeAssertion) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("exprIfElseTrivia", function(assert)
		local source = [[local x =
if true then 'hello' else 'world' -- after]]
		local expected = "local x =\nreplaced -- after"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isExprIfElse) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("exprTrivia", function(assert)
		local source = [[local x, y =
if true then 'hello' else 'world', z :: string -- after]]
		local expected = "local x, y =\nreplaced, replaced -- after"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isExpr) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("statBlockTrivia", function(assert)
		local source = [[-- hello
local y = 1
-- world]]
		local expected = "-- hello\nreplaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isStatBlock) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("statIfTrivia", function(assert)
		local source = [[-- hello
if true then
	return 1
else
	return 2
end
-- world]]
		local expected = "-- hello\nreplaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isStatIf) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("statWhileTrivia", function(assert)
		local source = [[-- hello
while true do
	print("hello")
end
-- world]]
		local expected = "-- hello\nreplaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isStatWhile) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("statRepeatTrivia", function(assert)
		local source = [[-- hello
repeat
	print("hello")
until true
-- world]]
		local expected = "-- hello\nreplaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isStatRepeat) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("statBreakTrivia", function(assert)
		local source = [[-- hello
while true do
	break
end
-- world]]
		local expected = "-- hello\nwhile true do\n\treplaced\nend\n-- world"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isStatBreak) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("statContinueTrivia", function(assert)
		local source = [[-- hello
while true do
	continue
end
-- world]]
		local expected = "-- hello\nwhile true do\n\treplaced\nend\n-- world"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isStatContinue) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("statReturnTrivia", function(assert)
		local source = [[-- hello
function foo() return 1, 2 end
-- world]]
		local expected = "-- hello\nfunction foo() replaced end\n-- world"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isStatReturn) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("statExprTrivia", function(assert)
		local source = [[-- hello
foobar()
-- world]]
		local expected = "-- hello\nreplaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isStatExpr) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("statLocalTrivia", function(assert)
		local source = [[-- hello
local x = 1
-- world]]
		local expected = "-- hello\nreplaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isStatLocal) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("statForTrivia", function(assert)
		local source = [[-- hello
for i = 1, 10 do
	print(i)
end
-- world]]
		local expected = "-- hello\nreplaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isStatFor) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("statForInTrivia", function(assert)
		local source = [[-- hello
for i in {1, 2, 3} do
	print(i)
end
-- world]]
		local expected = "-- hello\nreplaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isStatForIn) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("statAssignTrivia", function(assert)
		local source = [[-- hello
local y = 2
y = 1
-- world]]
		local expected = "-- hello\nlocal y = 2\nreplaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isStatAssign) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("statCompoundAssignTrivia", function(assert)
		local source = [[-- hello
local y = 2
y -= 1
-- world]]
		local expected = "-- hello\nlocal y = 2\nreplaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isStatCompoundAssign) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("statFunctionTrivia", function(assert)
		local source = [[-- hello
function foo()
	return 1
end
-- world]]
		local expected = "-- hello\nreplaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isStatFunction) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("statLocalFunctionTrivia", function(assert)
		local source = [[-- hello
local function foo()
	return 1
end
-- world]]
		local expected = "-- hello\nreplaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isStatLocalFunction) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("statTypeAliasTrivia", function(assert)
		local source = [[-- hello
type foo = number
-- world]]
		local expected = "-- hello\nreplaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isStatTypeAlias) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("statTypeFunctionTrivia", function(assert)
		local source = [[-- hello
type function foo() return number end
-- world]]
		local expected = "-- hello\nreplaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isStatTypeFunction) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("statTrivia", function(assert)
		local source = [[-- hello
local x = 1
local y = 2
-- world]]
		local expected = "-- hello\nreplaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isStat) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("typeReferenceTrivia", function(assert)
		local source = [[-- hello
type foo = number
-- world]]
		local expected = "-- hello\ntype foo = replaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isTypeReference) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("typeSingletonBoolTrivia", function(assert)
		local source = [[-- hello
type foo = true
-- world]]
		local expected = "-- hello\ntype foo = replaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isTypeSingletonBool) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("typeSingletonStringTrivia", function(assert)
		local source = [[-- hello
local x : "hello"
-- world]]
		local expected = "-- hello\nlocal x : replaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isTypeSingletonString) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("typeTypeOfTrivia", function(assert)
		local source = [[-- hello
type foo = typeof(123)
-- world]]
		local expected = "-- hello\ntype foo = replaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isTypeTypeof) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("typeGroupTrivia", function(assert)
		local source = [[-- hello
type foo = (number)
-- world]]
		local expected = "-- hello\ntype foo = replaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isTypeGroup) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("typeOptionalTrivia", function(assert)
		local source = [[-- hello
type foo = true?
-- world]]
		local expected = "-- hello\ntype foo = truereplaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isTypeOptional) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("typeUnionTrivia", function(assert)
		local source = [[-- hello
type foo = true? | false
-- world]]
		local expected = "-- hello\ntype foo = replaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isTypeUnion) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("typeIntersectionTrivia", function(assert)
		local source = [[-- hello
type foo = true & false
-- world]]
		local expected = "-- hello\ntype foo = replaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isTypeIntersection) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("typeArrayTrivia", function(assert)
		local source = [[-- hello
type foo = { number }
-- world]]
		local expected = "-- hello\ntype foo = replaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isTypeArray) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("typeTableTrivia", function(assert)
		local source = [[-- hello
type foo = {}
-- world]]
		local expected = "-- hello\ntype foo = replaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isTypeTable) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("typeFunctionTrivia", function(assert)
		local source = [[-- hello
type foo = (number) -> ()
-- world]]
		local expected = "-- hello\ntype foo = replaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isTypeFunction) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("typeTrivia", function(assert)
		local source = [[-- hello
type foo = (number) -> ()
-- world]]
		local expected = "-- hello\ntype foo = replaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isType) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("typePackExplicitTrivia", function(assert)
		local source = [[-- hello
type foo = (number) -> (number, ...string)
-- world]]
		local expected = "-- hello\ntype foo = (number) -> (replaced)\n-- world"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isTypePackExplicit) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("typePackGenericTrivia", function(assert)
		local source = [[-- hello
type foo = <G...>(number) -> (number, G...)
-- world]]
		local expected = "-- hello\ntype foo = <G...>(number) -> (number, replaced)\n-- world"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isTypePackGeneric) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("typePackVariadicTrivia", function(assert)
		local source = [[-- hello
type foo = (number) -> (...number)
-- world]]
		local expected = "-- hello\ntype foo = (number) -> (replaced)\n-- world"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isTypePackVariadic) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("typePackTrivia", function(assert)
		local source = [[-- hello
type foo = (number) -> (number, ...string)
-- world]]
		local expected = "-- hello\ntype foo = (number) -> (replaced)\n-- world"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isTypePack) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("localTrivia", function(assert)
		local source = [[-- hello
local x, y = 1, 2
-- world]]
		local expected = "-- hello\nlocal replaced, replaced = 1, 2\n-- world"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isLocal) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("attributeTrivia", function(assert)
		local source = [[-- hello
@checked
function foo() return end
-- world]]
		local expected = "-- hello\nreplaced\nfunction foo() return end\n-- world"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isAttribute) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)

	suite:case("commentsInCall", function(assert)
		local source = [[foobar(
  foo, -- what about this
  bar, -- and this
  baz -- and this??
)]]

		local expected = "foobar(\n  foo, -- what about this\n  bar, -- and this\n  quxx -- and this??\n)"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isExprGlobal) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:filter(function(g)
					return g.name.text == "baz"
				end)
				:replace(function()
					return "quxx"
				end)
		end, assert)
	end)

	suite:case("commentsInTable", function(assert)
		local source = [[local x = {
  foo = -- what about this
  1, 
  bar = 2, 
  -- and this
  
  baz = 3 -- and this??
}]]

		local expected = [[local x = {
  replaced = -- what about this
  1, 
  replaced = 2, 
  -- and this
  
  replaced = 3 -- and this??
}]]

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast :: any, syntaxUtils.isExprTable) -- LUAUFIX: Remove any cast once code too complex no longer emitted
				:flatmap(function(t)
					local l = {}
					for _, entry in t.entries do
						if entry.kind ~= "list" then
							table.insert(l, entry.key)
						end
					end
					return l
				end)
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)
end)
