local assertLib = require("@std/test/assert")
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
	assert: assertLib.asserts
)
	local ast = syntax.parse(source)
	local replacements = transformFn(ast.root)

	local result = printer.printfile(ast, replacements)

	assert.eq(result, expected)
end

test.suite("syntax_printer", function(suite)
	suite:case("string_replacement", function(assert)
		local source = [[
            local name = "World"
]]

		local expected = "            local name = 1 + 2\n"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isExprConstantString):replace(function(s)
				return if s.text == "World" then "1 + 2" else nil
			end)
		end, assert)
	end)

	suite:case("expr_replacement", function(assert)
		local source = [[
            local name = "World"
]]

		local expected = "            local name = 1 + 2\n"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isExprConstantString):replace(function(s)
				return if s.text == "World" then syntax.parseexpr("1 + 2") else nil
			end)
		end, assert)
	end)

	suite:case("stat_replacement", function(assert)
		local source = [[
            local name = "World"
]]

		local expected = "            local name = 1 + 2\n"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isStatLocal):replace(function(_)
				return syntax.parseblock("local name = 1 + 2")
			end)
		end, assert)
	end)

	suite:case("type_replacement", function(assert)
		local source = [[local name: number = "World"]]
		local expected = [[local name: string = "World"]]

		local stat = syntax.parseblock("local x: string")
		local ann = (stat.statements[1] :: syntaxTypes.AstStatLocal).variables[1].node.annotation

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast, syntaxUtils.isStatLocal)
				:map(function(assign)
					return assign.variables[1].node.annotation
				end)
				:replace(function(_)
					return ann
				end)
		end, assert)
	end)

	suite:case("type_pack_replacement", function(assert)
		local source = [[type t = (...number) -> ()]]
		local expected = [[type t = (...number) -> string, ...string)]]

		local stat = syntax.parseblock("type t = () -> (string, ...string)")
		local tp = ((stat.statements[1] :: syntaxTypes.AstStatTypeAlias).type :: syntaxTypes.AstTypeFunction).returntypes

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast, syntaxUtils.isStatTypeAlias)
				:map(function(ta)
					if ta.type.tag == "function" then
						return ta.type.returntypes
					end
				end)
				:replace(function(_)
					return tp
				end)
		end, assert)
	end)

	suite:case("expr_table_item_replacement", function(assert)
		local source = "local tbl = { a = 1, }"
		local expected = "local tbl = { b = 2, }"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast, syntaxUtils.isExprTable)
				:map(function(node)
					return node.entries[1]
				end)
				:replace(function(_)
					return "b = 2,"
				end)
		end, assert)
	end)

	suite:case("exprgroup_trivia", function(assert)
		local source = [[local x =
(1 + 2) -- after]]
		local expected = "local x =\nreplaced -- after"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isExprGroup):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("exprnil_trivia", function(assert)
		local source = [[local x =
nil -- after]]
		local expected = "local x =\nreplaced -- after"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isExprConstantNil):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("exprbool_trivia", function(assert)
		local source = [[local x =
true -- after]]
		local expected = "local x =\nreplaced -- after"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isExprConstantBool):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("exprnumber_trivia", function(assert)
		local source = [[local x =
235 -- after]]
		local expected = "local x =\nreplaced -- after"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isExprConstantNumber):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("exprlocal_trivia", function(assert)
		local source = [[local y = 3
		local x =
y -- after]]
		local expected = "local y = 3\n\t\tlocal x =\nreplaced -- after"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isExprLocal):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("exprglobal_trivia", function(assert)
		local source = [[local x =
y -- after]]
		local expected = "local x =\nreplaced -- after"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isExprGlobal):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("exprvarargs_trivia", function(assert)
		local source = [[local x =
... -- after]]
		local expected = "local x =\nreplaced -- after"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isExprVarargs):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("exprcall_trivia", function(assert)
		local source = [[local x =
print() -- after]]
		local expected = "local x =\nreplaced -- after"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isExprCall):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("exprindexname_trivia", function(assert)
		local source = [[local x =
hello.world -- after]]
		local expected = "local x =\nreplaced -- after"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isExprIndexName):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("exprindexexpr_trivia", function(assert)
		local source = [[local x =
hello['world'] -- after]]
		local expected = "local x =\nreplaced -- after"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isExprIndexExpr):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("exprfunction_trivia", function(assert)
		local source = [[local x =
function() return end -- after]]
		local expected = "local x =\nreplaced -- after"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isExprFunction):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("exprtable_trivia", function(assert)
		local source = [[local x =
{} -- after]]
		local expected = "local x =\nreplaced -- after"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isExprTable):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("exprunary_trivia", function(assert)
		local source = [[local x =
#t -- after]]
		local expected = "local x =\nreplaced -- after"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isExprUnary):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("exprbinary_trivia", function(assert)
		local source = [[local x =
3 + 2 -- after]]
		local expected = "local x =\nreplaced -- after"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isExprBinary):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("exprinterpstring_trivia", function(assert)
		local source = [[local x =
`hello {"world"}` -- after]]
		local expected = "local x =\nreplaced -- after"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isExprInterpString):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("exprtypeassertion_trivia", function(assert)
		local source = [[local x =
y :: number -- after]]
		local expected = "local x =\nreplaced -- after"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isExprTypeAssertion):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("exprifelse_trivia", function(assert)
		local source = [[local x =
if true then 'hello' else 'world' -- after]]
		local expected = "local x =\nreplaced -- after"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isExprIfElse):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("expr_trivia", function(assert)
		local source = [[local x, y =
if true then 'hello' else 'world', z :: string -- after]]
		local expected = "local x, y =\nreplaced, replaced -- after"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isExpr):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("statblock_trivia", function(assert)
		local source = [[-- hello
local y = 1
-- world]]
		local expected = "-- hello\nreplaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isStatBlock):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("statif_trivia", function(assert)
		local source = [[-- hello
if true then
	return 1
else
	return 2
end
-- world]]
		local expected = "-- hello\nreplaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isStatIf):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("statwhile_trivia", function(assert)
		local source = [[-- hello
while true do
	print("hello")
end
-- world]]
		local expected = "-- hello\nreplaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isStatWhile):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("statrepeat_trivia", function(assert)
		local source = [[-- hello
repeat
	print("hello")
until true
-- world]]
		local expected = "-- hello\nreplaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isStatRepeat):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("statbreak_trivia", function(assert)
		local source = [[-- hello
while true do
	break
end
-- world]]
		local expected = "-- hello\nwhile true do\n\treplaced\nend\n-- world"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isStatBreak):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("statcontinue_trivia", function(assert)
		local source = [[-- hello
while true do
	continue
end
-- world]]
		local expected = "-- hello\nwhile true do\n\treplaced\nend\n-- world"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isStatContinue):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("statreturn_trivia", function(assert)
		local source = [[-- hello
function foo() return 1, 2 end
-- world]]
		local expected = "-- hello\nfunction foo() replaced end\n-- world"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isStatReturn):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("statexpr_trivia", function(assert)
		local source = [[-- hello
foobar()
-- world]]
		local expected = "-- hello\nreplaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isStatExpr):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("statlocal_trivia", function(assert)
		local source = [[-- hello
local x = 1
-- world]]
		local expected = "-- hello\nreplaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isStatLocal):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("statfor_trivia", function(assert)
		local source = [[-- hello
for i = 1, 10 do
	print(i)
end
-- world]]
		local expected = "-- hello\nreplaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isStatFor):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("statforin_trivia", function(assert)
		local source = [[-- hello
for i in {1, 2, 3} do
	print(i)
end
-- world]]
		local expected = "-- hello\nreplaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isStatForIn):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("statassign_trivia", function(assert)
		local source = [[-- hello
local y = 2
y = 1
-- world]]
		local expected = "-- hello\nlocal y = 2\nreplaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isStatAssign):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("statcompoundassign_trivia", function(assert)
		local source = [[-- hello
local y = 2
y -= 1
-- world]]
		local expected = "-- hello\nlocal y = 2\nreplaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isStatCompoundAssign):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("statfunction_trivia", function(assert)
		local source = [[-- hello
function foo()
	return 1
end
-- world]]
		local expected = "-- hello\nreplaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isStatFunction):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("statlocalfunction_trivia", function(assert)
		local source = [[-- hello
local function foo()
	return 1
end
-- world]]
		local expected = "-- hello\nreplaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isStatLocalFunction):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("stattypealias_trivia", function(assert)
		local source = [[-- hello
type foo = number
-- world]]
		local expected = "-- hello\nreplaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isStatTypeAlias):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("stattypefunction_trivia", function(assert)
		local source = [[-- hello
type function foo() return number end
-- world]]
		local expected = "-- hello\nreplaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isStatTypeFunction):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("stat_trivia", function(assert)
		local source = [[-- hello
local x = 1
local y = 2
-- world]]
		local expected = "-- hello\nreplaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isStat):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("typereference_trivia", function(assert)
		local source = [[-- hello
type foo = number
-- world]]
		local expected = "-- hello\ntype foo = replaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isTypeReference):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("typesingletonbool_trivia", function(assert)
		local source = [[-- hello
type foo = true
-- world]]
		local expected = "-- hello\ntype foo = replaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isTypeSingletonBool):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("typesingletonstring_trivia", function(assert)
		local source = [[-- hello
local x : "hello"
-- world]]
		local expected = "-- hello\nlocal x : replaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isTypeSingletonString):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("typetypeof_trivia", function(assert)
		local source = [[-- hello
type foo = typeof(123)
-- world]]
		local expected = "-- hello\ntype foo = replaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isTypeTypeof):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("typegroup_trivia", function(assert)
		local source = [[-- hello
type foo = (number)
-- world]]
		local expected = "-- hello\ntype foo = replaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isTypeGroup):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("typeoptional_trivia", function(assert)
		local source = [[-- hello
type foo = true?
-- world]]
		local expected = "-- hello\ntype foo = truereplaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isTypeOptional):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("typeunion_trivia", function(assert)
		local source = [[-- hello
type foo = true? | false
-- world]]
		local expected = "-- hello\ntype foo = replaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isTypeUnion):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("typeintersection_trivia", function(assert)
		local source = [[-- hello
type foo = true & false
-- world]]
		local expected = "-- hello\ntype foo = replaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isTypeIntersection):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("typearray_trivia", function(assert)
		local source = [[-- hello
type foo = { number }
-- world]]
		local expected = "-- hello\ntype foo = replaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isTypeArray):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("typetable_trivia", function(assert)
		local source = [[-- hello
type foo = {}
-- world]]
		local expected = "-- hello\ntype foo = replaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isTypeTable):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("typefunction_trivia", function(assert)
		local source = [[-- hello
type foo = (number) -> ()
-- world]]
		local expected = "-- hello\ntype foo = replaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isTypeFunction):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("type_trivia", function(assert)
		local source = [[-- hello
type foo = (number) -> ()
-- world]]
		local expected = "-- hello\ntype foo = replaced\n-- world"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isType):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("typepackexplicit_trivia", function(assert)
		local source = [[-- hello
type foo = (number) -> (number, ...string)
-- world]]
		local expected = "-- hello\ntype foo = (number) -> (replaced)\n-- world"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isTypePackExplicit):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("typepackgeneric_trivia", function(assert)
		local source = [[-- hello
type foo = <G...>(number) -> (number, G...)
-- world]]
		local expected = "-- hello\ntype foo = <G...>(number) -> (number, replaced)\n-- world"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isTypePackGeneric):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("typepackvariadic_trivia", function(assert)
		local source = [[-- hello
type foo = (number) -> (...number)
-- world]]
		local expected = "-- hello\ntype foo = (number) -> (replaced)\n-- world"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isTypePackVariadic):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("typepack_trivia", function(assert)
		local source = [[-- hello
type foo = (number) -> (number, ...string)
-- world]]
		local expected = "-- hello\ntype foo = (number) -> (replaced)\n-- world"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isTypePack):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("local_trivia", function(assert)
		local source = [[-- hello
local x, y = 1, 2
-- world]]
		local expected = "-- hello\nlocal replaced, replaced = 1, 2\n-- world"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isLocal):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("attribute_trivia", function(assert)
		local source = [[-- hello
@checked
function foo() return end
-- world]]
		local expected = "-- hello\nreplaced\nfunction foo() return end\n-- world"

		checkReplacement(source, expected, function(ast)
			return query.findallfromroot(ast, syntaxUtils.isAttribute):replace(function()
				return "replaced"
			end)
		end, assert)
	end)

	suite:case("comments_in_call", function(assert)
		local source = [[foobar(
  foo, -- what about this
  bar, -- and this
  baz -- and this??
)]]

		local expected = "foobar(\n  foo, -- what about this\n  bar, -- and this\n  quxx -- and this??\n)"

		checkReplacement(source, expected, function(ast)
			return query
				.findallfromroot(ast, syntaxUtils.isExprGlobal)
				:filter(function(g)
					return g.name.text == "baz"
				end)
				:replace(function()
					return "quxx"
				end)
		end, assert)
	end)

	suite:case("comments_in_table", function(assert)
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
				.findallfromroot(ast, syntaxUtils.isExprTable)
				:flatmap(function(t)
					local l = {}
					for _, entry in t.entries do
						table.insert(l, entry.key)
					end
					return l
				end)
				:replace(function()
					return "replaced"
				end)
		end, assert)
	end)
end)
