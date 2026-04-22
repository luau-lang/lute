local test = require("@std/test")
local syntax = require("@std/syntax")
local query = require("@std/syntax/query")
local utils = require("@std/syntax/utils")

test.suite("Utils", function(suite)
	suite:case("isRequireCall", function(assert)
		local ast1 = syntax.parse('local x = require("module")')
		local results = query.findAllFromRoot(ast1, utils.isRequireCall)
		assert.eq(#results.nodes, 1)
		assert.eq(results.nodes[1].tag, "call")

		-- Non-require calls should not match
		local ast2 = syntax.parse('local x = print("hello")')
		local results2 = query.findAllFromRoot(ast2, utils.isRequireCall)
		assert.eq(#results2.nodes, 0)
	end)
end)
