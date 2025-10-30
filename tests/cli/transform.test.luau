local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@lute/process")
local system = require("@std/system")
local test = require("@std/test")

local TRANSFORMEE_CONTENT = [[
local x = math.sqrt(-1)
local b = x ~= x
]]

local lutePath = process.execpath()
local tmpDir = system.tmpdir()

test.suite("lute transform", function(suite)
	suite:case("transform visitor style", function(assert)
		-- Setup
		-- Copy examples/transformer.luau to build/transform_tests/transformer.luau
		local transformerExample = path.format(path.join("examples", "transformer.luau"))
		local transformerDest = path.format(path.join(tmpDir, "transformer.luau"))
		fs.copy(transformerExample, transformerDest)

		-- Create a transformee file
		local transformeePath = path.format(path.join(tmpDir, "transformee.luau"))
		local transformeeHandle = fs.open(transformeePath, "w+")
		fs.write(transformeeHandle, TRANSFORMEE_CONTENT)
		fs.close(transformeeHandle)

		-- Do
		-- Run the transformer on the transformee
		local result = process.run({ lutePath, "transform", transformerDest, transformeePath })

		-- Check
		assert.eq(result.exitcode, 0)

		local transformeeHandle = fs.open(transformeePath, "r")
		local transformeeContent = fs.read(transformeeHandle)
		assert.eq(transformeeContent:find("x ~= x"), nil)
		assert.neq(transformeeContent:find("math.isnan(x)", 1, true), nil)
		fs.close(transformeeHandle)

		-- Teardown
		fs.remove(transformerDest)
		fs.remove(transformeePath)
	end)
end)

test.run()
