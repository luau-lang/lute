local test = require("@std/test")
local syntax = require("@std/syntax")
local query = require("@std/syntax/query")
local utils = require("@std/syntax/utils")

test.suite("Utils", function(suite)
	suite:case("isRequireCall", function(assert)
		local cst1 = syntax.parse('local x = require("module")')
		local results = query.findAllFromRoot(cst1, utils.isRequireCall)
		assert.eq(#results.nodes, 1)
		assert.eq(results.nodes[1].tag, "call")

		-- Non-require calls should not match
		local cst2 = syntax.parse('local x = print("hello")')
		local results2 = query.findAllFromRoot(cst2, utils.isRequireCall)
		assert.eq(#results2.nodes, 0)
	end)

	suite:case("isExportStatLocal", function(assert)
		local exported = syntax.parse("export local x").root.statements[1]
		local plain = syntax.parse("local x").root.statements[1]
		local constant = syntax.parse("export const x = 1").root.statements[1]
		local func = syntax.parse("export function f() end").root.statements[1]

		assert.that(utils.isExportStatLocal(exported) == exported)
		assert.eq(utils.isExportStatLocal(plain), nil)
		assert.eq(utils.isExportStatLocal(constant), nil)
		assert.eq(utils.isExportStatLocal(func), nil)
	end)

	suite:case("isExportStatConst", function(assert)
		local exported = syntax.parse("export const x = 1").root.statements[1]
		local plain = syntax.parse("const x = 1").root.statements[1]
		local variable = syntax.parse("export local x").root.statements[1]
		local func = syntax.parse("export function f() end").root.statements[1]

		assert.that(utils.isExportStatConst(exported) == exported)
		assert.eq(utils.isExportStatConst(plain), nil)
		assert.eq(utils.isExportStatConst(variable), nil)
		assert.eq(utils.isExportStatConst(func), nil)
	end)

	suite:case("isExportStatLocalFunction", function(assert)
		local exported = syntax.parse("export function f() end").root.statements[1]
		local plain = syntax.parse("local function f() end").root.statements[1]
		local global = syntax.parse("function f() end").root.statements[1]
		local variable = syntax.parse("export local x").root.statements[1]
		local constant = syntax.parse("export const x = 1").root.statements[1]

		assert.that(utils.isExportStatLocalFunction(exported) == exported)
		assert.eq(utils.isExportStatLocalFunction(plain), nil)
		assert.eq(utils.isExportStatLocalFunction(global), nil)
		assert.eq(utils.isExportStatLocalFunction(variable), nil)
		assert.eq(utils.isExportStatLocalFunction(constant), nil)
	end)

	suite:case("getExportedItemsLocal", function(assert)
		local declaration = syntax.parse("export local x").root.statements[1] :: syntax.CstStatLocal
		assert.eq(utils.getExportedItems(declaration), {
			isConst = false,
			items = { declaration.variables[1] },
		})
	end)

	suite:case("getExportedItemsMultipleLocals", function(assert)
		local declaration = syntax.parse("export local x,y,z").root.statements[1] :: syntax.CstStatLocal
		assert.eq(utils.getExportedItems(declaration), {
			isConst = false,
			items = { declaration.variables[1], declaration.variables[2], declaration.variables[3] },
		})
	end)

	suite:case("getExportedItemsConst", function(assert)
		local declaration = syntax.parse("export const x = 1").root.statements[1] :: syntax.CstStatConst
		assert.eq(utils.getExportedItems(declaration), {
			isConst = true,
			items = { declaration.variables[1] },
		})
	end)

	suite:case("getExportedItemsMultipleConsts", function(assert)
		local declaration = syntax.parse("export const x,y,z = 1,2,3").root.statements[1] :: syntax.CstStatConst
		assert.eq(utils.getExportedItems(declaration), {
			isConst = true,
			items = { declaration.variables[1], declaration.variables[2], declaration.variables[3] },
		})
	end)

	suite:case("getExportedItemsFunctionIsConst", function(assert)
		local funcStat = syntax.parse("export function f()\nend").root.statements[1] :: syntax.CstStatLocalFunction
		assert.eq(utils.getExportedItems(funcStat), { isConst = true, items = { funcStat.name } })
	end)

	suite:case("getExportedItemsIgnoresNonExports", function(assert)
		local variable = syntax.parse("local x").root.statements[1]
		local constant = syntax.parse("const x = 1").root.statements[1]
		local func = syntax.parse("local function f() end").root.statements[1]
		local global = syntax.parse("function f() end").root.statements[1]

		assert.eq(utils.getExportedItems(variable), nil)
		assert.eq(utils.getExportedItems(constant), nil)
		assert.eq(utils.getExportedItems(func), nil)
		assert.eq(utils.getExportedItems(global), nil)
	end)

	suite:case("exportUtilitiesIgnoreTypeExports", function(assert)
		local alias = syntax.parse("export type T = number").root.statements[1]
		local func = syntax.parse("export type function identity(ty) return ty end").root.statements[1]

		assert.eq(utils.isExportStatLocal(alias), nil)
		assert.eq(utils.isExportStatConst(alias), nil)
		assert.eq(utils.isExportStatLocalFunction(alias), nil)
		assert.eq(utils.getExportedItems(alias), nil)
		assert.eq(utils.isExportStatLocal(func), nil)
		assert.eq(utils.isExportStatConst(func), nil)
		assert.eq(utils.isExportStatLocalFunction(func), nil)
		assert.eq(utils.getExportedItems(func), nil)
	end)

	suite:case("exportUtilitiesIgnoreNonStatements", function(assert)
		local root = syntax.parse("local x = 1\nlocal y = x").root
		local declaration = root.statements[2] :: syntax.CstStatLocal
		local reference = declaration.values[1]

		assert.eq(utils.isExportStatLocal(reference), nil)
		assert.eq(utils.isExportStatConst(reference), nil)
		assert.eq(utils.isExportStatLocalFunction(reference), nil)
		assert.eq(utils.getExportedItems(reference), nil)
		assert.eq(utils.getExportedItems(declaration.variables[1]), nil)
		assert.eq(utils.getExportedItems(declaration.localKeyword), nil)
		assert.eq(utils.getExportedItems(root), nil)
	end)
end)
