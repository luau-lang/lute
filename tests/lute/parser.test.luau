local test = require("@std/test")

local cst = require("@lute/syntax/cst")
local mutablecst = require("@lute/syntax/mutablecst")
local parser = require("@lute/syntax/parser")
local printer = require("@std/syntax/printer")

local source = "local x = 1\nlocal y, z = x + 2, 3\nreturn y\n"

test.suite("SyntaxParserMutableTests", function(suite)
	suite:case("parseMutableMatchesParse", function(assert)
		assert.eq(parser.parseMutable(source), parser.parse(source))
	end)

	suite:case("parseMutableAllowsEditingTokens", function(assert)
		local result = parser.parseMutable(source)

		local statement = result.root.statements[1]
		assert.eq(statement.tag, "local")
		if statement.tag ~= "local" then
			return
		end

		statement.variables[1].name.text = "renamed"
		local value = statement.values[1]
		if value.tag == "number" then
			value.token.text = "42"
		end

		assert.eq(printer.printFile(result :: cst.CstParseResult), "local renamed = 42\nlocal y, z = x + 2, 3\nreturn y\n")
	end)

	suite:case("parseMutableAllowsEditingTrivia", function(assert)
		local result = parser.parseMutable(source)

		local statement = result.root.statements[1]
		if statement.tag ~= "local" then
			assert.that(false, "expected first statement to be a local declaration")
			return
		end

		local location = statement.localKeyword.location
		local comment: mutablecst.SingleLineComment = { tag = "comment", location = location, text = "-- added" }
		local newline: mutablecst.Whitespace = { tag = "whitespace", location = location, text = "\n" }
		table.insert(statement.localKeyword.leadingTrivia, 1, comment)
		table.insert(statement.localKeyword.leadingTrivia, 2, newline)

		assert.eq(printer.printFile(result :: cst.CstParseResult), "-- added\n" .. source)
	end)

	suite:case("parseMutableAllowsEditingStatementLists", function(assert)
		local result = parser.parseMutable(source)

		table.remove(result.root.statements, 2)
		local returned = result.root.statements[2]
		if returned.tag == "return" then
			local expression = returned.expressions[1]
			if expression.tag == "local" then
				expression.token.text = "x"
			end
		end

		assert.eq(printer.printFile(result :: cst.CstParseResult), "local x = 1\nreturn x\n")
	end)

	suite:case("parseMutableExprAllowsEditing", function(assert)
		local expr = parser.parseMutableExpr("a + 1")
		if expr.tag ~= "binary" then
			assert.that(false, "expected a binary expression")
			return
		end

		expr.operator.text = "-"
		local rhs = expr.rhsOperand
		if rhs.tag == "number" then
			rhs.value = 2
			rhs.token.text = "2"
		end

		assert.eq(printer.printNode(expr :: any), "a - 2")
	end)
end)
