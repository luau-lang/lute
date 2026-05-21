local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")
local test = require("@std/test")
local testutil = require("../testutil")

local TRANSFORMEE_CONTENT = [[
local x = math.sqrt(-1)
local b = x ~= x
]]

local lutePath = path.format(process.execPath())
local tmpDir = system.tmpdir()
local transformeePath = path.format(path.join(tmpDir, "transformee.luau"))
local outputPath = path.format(path.join(tmpDir, "transformee_output.luau"))

local USAGE = "Usage: lute transform [options] <migration-path> [files...] [-- [--option value...]]"

test.suite("LuteTransform", function(suite)
	suite:beforeEach(function()
		-- Create a transformee file
		local transformeeHandle = fs.open(transformeePath, "w+")
		fs.write(transformeeHandle, TRANSFORMEE_CONTENT)
		fs.close(transformeeHandle)
	end)

	suite:afterEach(function()
		-- Remove the transformee file
		fs.remove(transformeePath)
		if fs.exists(outputPath) then
			fs.remove(outputPath)
		end
	end)

	suite:case("luteLintTransformMessage", function(assert)
		local result = process.run({ lutePath, "transform", "-h" })

		assert.eq(result.exitcode, 0)
		assert.strContains(result.stdout, USAGE)

		result = process.run({ lutePath, "transform", "--h" })

		assert.eq(result.exitcode, 0)
		assert.strContains(result.stdout, USAGE)

		result = process.run({ lutePath, "transform", "--help" })

		assert.eq(result.exitcode, 0)
		assert.strContains(result.stdout, USAGE)
	end)

	suite:case("luteLintMissingTransformationScript", function(assert)
		local result = process.run({ lutePath, "transform" })

		assert.eq(result.exitcode, 1)
		assert.strContains(
			testutil.normalizeLineEndings(result.stdout),
			`Error: No code transformation script specified.\n\n{USAGE}\nUse --help for more information.`
		)
	end)

	suite:case("transformQueryStyle", function(assert)
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
		assert.strContains(transformeeContent, "math.isnan(x)")
		fs.close(transformeeHandle)

		-- Teardown
		fs.remove(transformerDest)
	end)

	suite:case("transformOutputDirectoryHappyPath", function(assert)
		-- Setup
		-- Copy examples/transformer.luau to build/transform_tests/transformer.luau
		local transformerExample = path.format(path.join("examples", "query_transformer.luau"))
		local transformerDest = path.format(path.join(tmpDir, "query_transformer.luau"))
		fs.copy(transformerExample, transformerDest)

		-- Create output file
		local h = fs.open(outputPath, "w+")
		fs.close(h)

		-- Do
		-- Run the transformer on the transformee
		local result = process.run({ lutePath, "transform", "--output", outputPath, transformerDest, transformeePath })
		-- Check
		assert.eq(result.exitcode, 0)

		-- Check that the original file is unchanged
		local transformeeHandle = fs.open(transformeePath, "r")
		local transformeeContent = fs.read(transformeeHandle)
		assert.eq(transformeeContent, TRANSFORMEE_CONTENT)
		fs.close(transformeeHandle)

		-- Check that the output file has been written to
		h = fs.open(outputPath, "r")
		local outputContent = fs.read(h)
		assert.eq(outputContent:find("x ~= x"), nil)
		assert.strContains(outputContent, "math.isnan(x)")
		fs.close(h)

		-- Teardown
		fs.remove(transformerDest)
		fs.remove(outputPath)
	end)

	suite:case("transformForwardedOptions", function(assert)
		-- Setup
		local transformerExample = path.format(path.join("examples", "options_transformer.luau"))
		local transformerDest = path.format(path.join(tmpDir, "options_transformer.luau"))
		fs.copy(transformerExample, transformerDest)

		-- Do
		-- Run the transformer with a forwarded option overriding the default functionName
		local result = process.run({
			lutePath,
			"transform",
			transformerDest,
			transformeePath,
			"--",
			"--functionName",
			"number.isNaN",
		})

		-- Check
		assert.eq(result.exitcode, 0)

		local transformeeHandle = fs.open(transformeePath, "r")
		local transformeeContent = fs.read(transformeeHandle)
		assert.strNotContains(transformeeContent, "x ~= x")
		assert.strContains(transformeeContent, "number.isNaN(x)")
		fs.close(transformeeHandle)

		-- Teardown
		fs.remove(transformerDest)
	end)

	suite:case("transformOutputCreatesFileIfItDoesntExist", function(assert)
		-- Setup
		-- Copy examples/transformer.luau to build/transform_tests/transformer.luau
		local transformerExample = path.format(path.join("examples", "query_transformer.luau"))
		local transformerDest = path.format(path.join(tmpDir, "query_transformer.luau"))
		fs.copy(transformerExample, transformerDest)

		-- Create output directory

		-- Do
		-- Run the transformer on the transformee
		local result = process.run({ lutePath, "transform", "--output", outputPath, transformerDest, transformeePath })
		-- Check
		assert.eq(result.exitcode, 0)

		-- Check that the original file is unchanged
		local transformeeHandle = fs.open(transformeePath, "r")
		local transformeeContent = fs.read(transformeeHandle)
		assert.eq(transformeeContent, TRANSFORMEE_CONTENT)
		fs.close(transformeeHandle)

		-- Check that the output file has been created and written to
		assert.that(fs.exists(outputPath))
		local h = fs.open(outputPath, "r")
		local outputContent = fs.read(h)
		assert.eq(outputContent:find("x ~= x"), nil)
		assert.strContains(outputContent, "math.isnan(x)")
		fs.close(h)

		-- Teardown
		fs.remove(transformerDest)
		fs.remove(outputPath)
	end)
end)
