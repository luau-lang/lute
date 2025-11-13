local printer = require("@std/syntax/printer")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local syntaxTypes = require("@std/syntax/types")
local syntaxUtils = require("@std/syntax/utils")
local test = require("@std/test")

function compareStrings(result: string, expected: string)
	for i = 1, math.max(#result, #expected) do
		local rChar = result:sub(i, i):byte()
		local eChar = expected:sub(i, i):byte()
		if rChar ~= eChar then
			print(`Difference at index {i}: result='{rChar}', expected='{eChar}'`)
		end
	end
end

test.suite("syntax_printer", function(suite)
	suite:case("string_replacement", function(assert)
		local source = [[
            local name = "World"
        ]]

		local ast = syntax.parse(source)
		local result = query
			.selectFromRoot(ast, syntaxUtils.isExprConstantString)
			:replace(function(s)
				return if s.text == "World" then "1 + 2" else nil
			end)
			:print()

		local expected = "            local name = 1 + 2\n"

		assert.eq(result, expected)
	end)

	suite:case("expr_replacement", function(assert)
		local source = [[
            local name = "World"
        ]]

		local ast = syntax.parse(source)
		local replacements = query.selectFromRoot(ast, syntaxUtils.isExprConstantString):replace(function(s)
			return if s.text == "World" then syntax.parseexpr("1 + 2") else nil -- LUAUFIX: I think this is because AstExpr doesn't subtype against AstNode
		end)

		local result = printer.printnode(ast, replacements)

		local expected = "            local name = 1 + 2\n"

		assert.eq(result, expected)
	end)

	suite:case("stat_replacement", function(assert)
		local source = [[
            local name = "World"
        ]]

		local ast = syntax.parse(source)
		local replacements = query.selectFromRoot(ast, syntaxUtils.isStatLocal):replace(function(s)
			return syntax.parse("local name = 1 + 2")
		end)

		local result = printer.printnode(ast, replacements)

		local expected = "            local name = 1 + 2\n"

		assert.eq(result, expected)
	end)

	suite:case("type_replacement", function(assert)
		local source = [[local name: number = "World"]]

		local stat = syntax.parse("local x: string")
		local ann = (stat.statements[1] :: syntaxTypes.AstStatLocal).variables[1].node.annotation
		assert.neq(ann, nil)

		local ast = syntax.parse(source)
		local replacements = query
			.selectFromRoot(ast, syntaxUtils.isStatLocal)
			:map(function(assign)
				local ann = assign.variables[1].node.annotation
				assert.neq(ann, nil)
				return ann
			end)
			:replace(function(t)
				return ann
			end)

		local result = printer.printnode(ast, replacements)

		local expected = [[local name: string = "World"]]

		assert.eq(result, expected)
	end)

	suite:case("type_pack_replacement", function(assert)
		local source = [[type t = (...number) -> ()]]

		local stat = syntax.parse("type t = () -> (string, ...string)")
		local tp = ((stat.statements[1] :: syntaxTypes.AstStatTypeAlias).type :: syntaxTypes.AstTypeFunction).returntypes

		local ast = syntax.parse(source)
		local replacements = query
			.selectFromRoot(ast, syntaxUtils.isStatTypeAlias)
			:map(function(ta)
				if ta.type.tag == "function" then
					return ta.type.returntypes
				end
			end)
			:replace(function(t)
				return tp
			end)

		local result = printer.printnode(ast, replacements)

		local expected = [[type t = (...number) -> string, ...string)]] -- TODO: bug in the parser? AstTypePackExplicit is missing opening

		assert.eq(result, expected)
	end)

	suite:case("exprgroup_trivia", function(assert)
		local source = [[local x =
(1 + 2) -- after]]

		local ast = syntax.parse(source)

		local result = query
			.selectFromRoot(ast, syntaxUtils.isExprGroup)
			:replace(function()
				return "replaced"
			end)
			:print()

		local expected = "local x =\nreplaced -- after"

		assert.eq(result, expected)
	end)

	suite:case("exprnil_trivia", function(assert)
		local source = [[local x =
nil -- after]]

		local ast = syntax.parse(source)

		local result = query
			.selectFromRoot(ast, syntaxUtils.isExprConstantNil)
			:replace(function()
				return "replaced"
			end)
			:print()

		local expected = "local x =\nreplaced -- after"

		assert.eq(result, expected)
	end)

	suite:case("exprbool_trivia", function(assert)
		local source = [[local x =
true -- after]]

		local ast = syntax.parse(source)

		local result = query
			.selectFromRoot(ast, syntaxUtils.isExprConstantBool)
			:replace(function()
				return "replaced"
			end)
			:print()

		local expected = "local x =\nreplaced -- after"

		assert.eq(result, expected)
	end)

	suite:case("exprnumber_trivia", function(assert)
		local source = [[local x =
235 -- after]]

		local ast = syntax.parse(source)

		local result = query
			.selectFromRoot(ast, syntaxUtils.isExprConstantNumber)
			:replace(function()
				return "replaced"
			end)
			:print()

		local expected = "local x =\nreplaced -- after"

		assert.eq(result, expected)
	end)

	suite:case("exprlocal_trivia", function(assert)
		local source = [[local y = 3
		local x =
y -- after]]

		local ast = syntax.parse(source)

		local result = query
			.selectFromRoot(ast, syntaxUtils.isExprLocal)
			:replace(function()
				return "replaced"
			end)
			:print()

		local expected = "local y = 3\n\t\tlocal x =\nreplaced -- after"

		assert.eq(result, expected)
	end)

	suite:case("exprglobal_trivia", function(assert)
		local source = [[local x =
y -- after]]

		local ast = syntax.parse(source)

		local result = query
			.selectFromRoot(ast, syntaxUtils.isExprGlobal)
			:replace(function()
				return "replaced"
			end)
			:print()

		local expected = "local x =\nreplaced -- after"

		assert.eq(result, expected)
	end)

	suite:case("exprvarargs_trivia", function(assert)
		local source = [[local x =
... -- after]]

		local ast = syntax.parse(source)

		local result = query
			.selectFromRoot(ast, syntaxUtils.isExprVarargs)
			:replace(function()
				return "replaced"
			end)
			:print()

		local expected = "local x =\nreplaced -- after"

		assert.eq(result, expected)
	end)

	suite:case("exprcall_trivia", function(assert)
		local source = [[local x =
print() -- after]]

		local ast = syntax.parse(source)

		local result = query
			.selectFromRoot(ast, syntaxUtils.isExprCall)
			:replace(function()
				return "replaced"
			end)
			:print()

		local expected = "local x =\nreplaced -- after"

		assert.eq(result, expected)
	end)

	suite:case("exprindexname_trivia", function(assert)
		local source = [[local x =
hello.world -- after]]

		local ast = syntax.parse(source)

		local result = query
			.selectFromRoot(ast, syntaxUtils.isExprIndexName)
			:replace(function()
				return "replaced"
			end)
			:print()

		local expected = "local x =\nreplaced -- after"

		assert.eq(result, expected)
	end)

	suite:case("exprindexexpr_trivia", function(assert)
		local source = [[local x =
hello['world'] -- after]]

		local ast = syntax.parse(source)

		local result = query
			.selectFromRoot(ast, syntaxUtils.isExprIndexExpr)
			:replace(function()
				return "replaced"
			end)
			:print()

		local expected = "local x =\nreplaced -- after"

		assert.eq(result, expected)
	end)

	suite:case("expranonymousfunction_trivia", function(assert)
		local source = [[local x =
function() return end -- after]]

		local ast = syntax.parse(source)

		local result = query
			.selectFromRoot(ast, syntaxUtils.isExprAnonymousFunction)
			:replace(function()
				return "replaced"
			end)
			:print()

		local expected = "local x =\nreplaced -- after"

		assert.eq(result, expected)
	end)

	suite:case("exprtable_trivia", function(assert)
		local source = [[local x =
{} -- after]]

		local ast = syntax.parse(source)

		local result = query
			.selectFromRoot(ast, syntaxUtils.isExprTable)
			:replace(function()
				return "replaced"
			end)
			:print()

		local expected = "local x =\nreplaced -- after"

		assert.eq(result, expected)
	end)

	suite:case("exprunary_trivia", function(assert)
		local source = [[local x =
#t -- after]]

		local ast = syntax.parse(source)

		local result = query
			.selectFromRoot(ast, syntaxUtils.isExprUnary)
			:replace(function()
				return "replaced"
			end)
			:print()

		local expected = "local x =\nreplaced -- after"

		assert.eq(result, expected)
	end)

	suite:case("exprbinary_trivia", function(assert)
		local source = [[local x =
3 + 2 -- after]]

		local ast = syntax.parse(source)

		local result = query
			.selectFromRoot(ast, syntaxUtils.isExprBinary)
			:replace(function()
				return "replaced"
			end)
			:print()

		local expected = "local x =\nreplaced -- after"

		assert.eq(result, expected)
	end)

	suite:case("exprinterpstring_trivia", function(assert)
		local source = [[local x =
`hello {"world"}` -- after]]

		local ast = syntax.parse(source)

		local result = query
			.selectFromRoot(ast, syntaxUtils.isExprInterpString)
			:replace(function()
				return "replaced"
			end)
			:print()

		local expected = "local x =\nreplaced -- after"

		assert.eq(result, expected)
	end)

	suite:case("exprtypeassertion_trivia", function(assert)
		local source = [[local x =
y :: number -- after]]

		local ast = syntax.parse(source)

		local result = query
			.selectFromRoot(ast, syntaxUtils.isExprTypeAssertion)
			:replace(function()
				return "replaced"
			end)
			:print()

		local expected = "local x =\nreplaced -- after"

		assert.eq(result, expected)
	end)

	suite:case("exprifelse_trivia", function(assert)
		local source = [[local x =
if true then 'hello' else 'world' -- after]]

		local ast = syntax.parse(source)

		local result = query
			.selectFromRoot(ast, syntaxUtils.isExprIfElse)
			:replace(function()
				return "replaced"
			end)
			:print()

		local expected = "local x =\nreplaced -- after"

		assert.eq(result, expected)
	end)

	suite:case("expr_trivia", function(assert)
		local source = [[local x, y =
if true then 'hello' else 'world', z :: string -- after]]

		local ast = syntax.parse(source)

		local result = query
			.selectFromRoot(ast, syntaxUtils.isExpr)
			:replace(function()
				return "replaced"
			end)
			:print()

		local expected = "local x, y =\nreplaced, replaced -- after"

		assert.eq(result, expected)
	end)
end)

test.run()
