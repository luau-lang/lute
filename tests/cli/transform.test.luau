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
local transformeePath = path.format(path.join(tmpDir, "transformee.luau"))
local outputDir = path.format(path.join(tmpDir, "output_dir"))

test.suite("lute transform", function(suite)
	suite:beforeeach(function()
		-- Create a transformee file
		local transformeeHandle = fs.open(transformeePath, "w+")
		fs.write(transformeeHandle, TRANSFORMEE_CONTENT)
		fs.close(transformeeHandle)
	end)

	suite:aftereach(function()
		-- Remove the transformee file
		fs.remove(transformeePath)
		if fs.exists(outputDir) then
			fs.removedirectory(outputDir, { recursive = true })
		end
	end)

	suite:case("transform visitor style", function(assert)
		-- Setup
		-- Copy examples/transformer.luau to build/transform_tests/transformer.luau
		local transformerExample = path.format(path.join("examples", "transformer.luau"))
		local transformerDest = path.format(path.join(tmpDir, "transformer.luau"))
		fs.copy(transformerExample, transformerDest)

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
	end)

	suite:case("transform query style", function(assert)
		-- Setup
		-- Copy examples/transformer.luau to build/transform_tests/transformer.luau
		local transformerExample = path.format(path.join("examples", "query_transformer.luau"))
		local transformerDest = path.format(path.join(tmpDir, "query_transformer.luau"))
		fs.copy(transformerExample, transformerDest)

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
	end)

	suite:case("transform output directory happy path", function(assert)
		-- Setup
		-- Copy examples/transformer.luau to build/transform_tests/transformer.luau
		local transformerExample = path.format(path.join("examples", "query_transformer.luau"))
		local transformerDest = path.format(path.join(tmpDir, "query_transformer.luau"))
		fs.copy(transformerExample, transformerDest)

		-- Create output directory
		local outputDir = path.format(path.join(tmpDir, "output_dir"))
		fs.createdirectory(outputDir)

		-- Do
		-- Run the transformer on the transformee
		local result = process.run({ lutePath, "transform", "--output", outputDir, transformerDest, transformeePath })
		-- Check
		assert.eq(result.exitcode, 0)

		-- Check that the original file is unchanged
		local transformeeHandle = fs.open(transformeePath, "r")
		local transformeeContent = fs.read(transformeeHandle)
		assert.eq(transformeeContent, TRANSFORMEE_CONTENT)
		fs.close(transformeeHandle)

		-- Check that the output file has been created
		local expectedOutputPath = path.format(path.join(outputDir, "transformee.luau"))
		assert.eq(fs.exists(expectedOutputPath), true)
		local outputHandle = fs.open(expectedOutputPath, "r")
		local outputContent = fs.read(outputHandle)
		assert.eq(outputContent:find("x ~= x"), nil)
		assert.neq(outputContent:find("math.isnan(x)", 1, true), nil)
		fs.close(outputHandle)

		-- Teardown
		fs.remove(transformerDest)
		fs.removedirectory(outputDir, { recursive = true })
	end)

	suite:case("transform output directory errors if no directory exists", function(assert)
		-- Setup
		-- Copy examples/transformer.luau to build/transform_tests/transformer.luau
		local transformerExample = path.format(path.join("examples", "query_transformer.luau"))
		local transformerDest = path.format(path.join(tmpDir, "query_transformer.luau"))
		fs.copy(transformerExample, transformerDest)

		-- Create output directory

		-- Do
		-- Run the transformer on the transformee
		local result = process.run({ lutePath, "transform", "--output", outputDir, transformerDest, transformeePath })
		-- Check
		assert.eq(result.exitcode, 1)
		assert.neq(result.stderr:find("Output directory does not exist"), nil)

		-- Check that the original file is unchanged
		local transformeeHandle = fs.open(transformeePath, "r")
		local transformeeContent = fs.read(transformeeHandle)
		assert.eq(transformeeContent, TRANSFORMEE_CONTENT)
		fs.close(transformeeHandle)

		-- Teardown
		fs.remove(transformerDest)
	end)
end)

test.run()
