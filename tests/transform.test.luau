local fs = require("@lute/fs")
local path = require("@std/path")
local process = require("@lute/process")
local system = require("@std/system")
local test = require("@std/test")

local TRANSFORMEE_CONTENT = [[
local x = math.sqrt(-1)
local b = x ~= x
]]

local lutePath =
	path.format(path.join("build", if system.os == "Darwin" then "xcode" else "vs2022", "debug", "lute", "cli", "lute"))

test.suite("lute transform", function(suite)
	local transformTestDir = path.format(path.join("build", "transform_tests"))

	suite:beforeall(function()
		-- Make a temp folder in the build directory
		if not fs.exists("build") then
			fs.mkdir("build")
		end

		if not fs.exists(transformTestDir) then
			fs.mkdir(transformTestDir)
		end
	end)

	suite:case("transform visitor style", function(assert)
		-- Setup
		-- Copy examples/transformer.luau to build/transform_tests/transformer.luau
		local transformerExample = path.format(path.join("examples", "transformer.luau"))
		local transformerDest = path.format(path.join(transformTestDir, "transformer.luau"))
		fs.copy(transformerExample, transformerDest)

		-- Create a transformee file
		local transformeePath = path.format(path.join(transformTestDir, "transformee.luau"))
		local transformeeHandle = fs.open(transformeePath, "w+")
		fs.write(transformeeHandle, TRANSFORMEE_CONTENT)
		fs.close(transformeeHandle)

		-- Do
		-- Run the transformer on the transformee
		local result = process.run({ lutePath, "transform", transformerDest, transformeePath }, {
			cwd = process.cwd(),
		})

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

	suite:afterall(function()
		for _, file in fs.listdir(transformTestDir) do
			fs.remove(path.format(path.join(transformTestDir, file.name)))
		end
		fs.rmdir(transformTestDir)
	end)
end)

test.run()
