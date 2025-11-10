local fs = require("@std/fs")
local luau = require("@std/luau")
local path = require("@std/path")
local system = require("@std/system")
local test = require("@std/test")

local tmpDir = system.tmpdir()

test.suite("LuauTypeOfModuleSuite", function(suite)
	suite:case("typeofmodule_returns_as_string", function(assert)
		local testPath = path.join(tmpDir, "typeofmodule_test.luau")
		local testFile = fs.open(testPath, "w+")
		fs.write(
			testFile,
			[[
			local stringext = require("@std/stringext")

			local function example_string(): string
				return "example"
			end

			return {
				example_string = example_string,
				trimmed = stringext.trim("  hello world  "),
			}
		]]
		)
		fs.close(testFile)

		local moduleTypeString = luau.typeofmodule(testPath)

		-- Basic check for now until the data structure is created
		assert.neq(moduleTypeString, "")
	end)
end)

test.run()
