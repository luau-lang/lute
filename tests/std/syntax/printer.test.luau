local luau = require("@std/luau")
local parser = require("@std/syntax/parser")
local printer = require("@std/syntax/printer")
local query = require("@std/syntax/query")
local syntaxUtils = require("@std/syntax/utils")
local test = require("@std/test")

test.suite("syntax_printer", function(suite)
	suite:case("string_replacement", function(assert)
		local source = [[
            local name = "World"
        ]]

		local ast = parser.parse(source)
		local replacements = query.selectFromRoot(ast, syntaxUtils.isExprConstantString):replace(function(s)
			return if s.text == "World" then "1 + 2" else nil
		end)

		local result = printer.printnode(ast, replacements)

		local expected = "            local name = 1 + 2" -- TODO: preserve trivia so trailing newline is preserved

		assert.eq(result, expected)
	end)

	suite:case("expr_replacement", function(assert)
		local source = [[
            local name = "World"
        ]]

		local ast = parser.parse(source)
		local replacements = query.selectFromRoot(ast, syntaxUtils.isExprConstantString):replace(function(s)
			return if s.text == "World" then parser.parseexpr("1 + 2") else nil -- LUAUFIX: I think this is because AstExpr doesn't subtype against AstNode
		end)

		local result = printer.printnode(ast, replacements)

		local expected = "            local name = 1 + 2" -- TODO: preserve trivia so trailing newline is preserved

		assert.eq(result, expected)
	end)

	suite:case("stat_replacement", function(assert)
		local source = [[
            local name = "World"
        ]]

		local ast = parser.parse(source)
		local replacements = query.selectFromRoot(ast, syntaxUtils.isStatLocal):replace(function(s)
			return parser.parse("local name = 1 + 2")
		end)

		local result = printer.printnode(ast, replacements)

		local expected = "local name = 1 + 2" -- TODO: preserve trivia so indentation and trailing newline is preserved

		assert.eq(result, expected)
	end)

	suite:case("type_replacement", function(assert)
		local source = [[local name: number = "World"]]

		local stat = parser.parse("local x: string")
		local ann = (stat.statements[1] :: luau.AstStatLocal).variables[1].node.annotation
		assert.neq(ann, nil)

		local ast = parser.parse(source)
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

		local expected = [[local name: string= "World"]] -- TODO: preserve trivia so space after type is preserved

		assert.eq(result, expected)
	end)

	suite:case("type_pack_replacement", function(assert)
		local source = [[type t = (...number) -> ()]]

		local stat = parser.parse("type t = () -> (string, ...string)")
		local tp = ((stat.statements[1] :: luau.AstStatTypeAlias).type :: luau.AstTypeFunction).returntypes

		local ast = parser.parse(source)
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
end)

test.run()
