local fs = require("@std/fs")
local luau = require("@std/luau")
local path = require("@std/path")
local system = require("@std/system")
local test = require("@std/test")

local tmpDir = system.tmpdir()

test.suite("LuauTypeOfModuleSuite", function(suite)
	suite:case("typeofmodule_returns_as_string_no_require", function(assert)
		local testPath = path.join(tmpDir, "typeofmodule_test.luau")
		local testFile = fs.open(testPath, "w+")
		fs.write(
			testFile,
			[[
			local function example_string(): string
				return "example"
			end

			return {
				example_string = example_string,
			}
		]]
		)
		fs.close(testFile)

		local moduleTypeString = luau.typeofmodule(testPath)
		local expectedOutputString = [[{
    example_string: () -> string
}]]

		-- Basic check for now until the data structure is created
		assert.eq(moduleTypeString, expectedOutputString)
	end)

	suite:case("resolverequire", function(assert)
		local testPath = path.join(tmpDir, "resolverequire_test.luau")
		local testFile = fs.open(testPath, "w+")

		fs.write(testFile, 'print("Hello, World!")')
		local resolvedPath = luau.resolverequire("@self", testPath)
		fs.close(testFile)

		assert.eq(resolvedPath, path.format(testPath))
	end)
end)

test.run()
