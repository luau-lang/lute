local fs = require("@std/fs")
local luau = require("@std/luau")
local path = require("@std/path")
local system = require("@std/system")
local test = require("@std/test")

local tmpDir = system.tmpdir()

test.suite("LuauTypeOfModuleSuite", function(suite)
	suite:case("typeofmodule_returns_typepack_structure", function(assert)
		local testPath = path.join(tmpDir, "typeofmodule_test.luau")
		local testFile = fs.open(testPath, "w+")
		fs.write(
			testFile,
			[[
			local function example_string(): string
				return "example"
			end

			return {
				example_string_func = example_string,
			}
		]]
		)
		fs.close(testFile)

		local typePack = luau.typeofmodule(testPath)
		assert.neq(typePack, nil)

		-- Verify TypePack structure: { head: {type}?, tail: type? }
		assert.neq(typePack.head, nil)
		assert.eq(typePack.tail, nil) -- No tail for simple return

		-- Verify head is an array with one element (the table type)
		assert.eq(#typePack.head, 1)

		local returnType = typePack.head[1]
		assert.neq(returnType, nil)
		assert.eq(returnType.tag, "table")

		-- Verify table has properties
		assert.neq(returnType.properties, nil)

		-- Find the example_string property
		local foundProperty = false
		for keyType, prop in pairs(returnType.properties) do
			if keyType.tag == "singleton" and keyType.value == "example_string_func" then
				foundProperty = true
				assert.neq(prop.read, nil)
				local funcType = prop.read
				assert.eq(funcType.tag, "function")
				-- Verify function returns string
				assert.neq(funcType.returns, nil)
				assert.neq(funcType.returns.head, nil)
				assert.eq(#funcType.returns.head, 1)
				assert.eq(funcType.returns.head[1].tag, "string")
				break
			end
		end
		assert.eq(foundProperty, true, "Should find example_string_func property")
	end)

	suite:case("typeofmodule_returns_typepack_with_multiple_values", function(assert)
		local testPath = path.join(tmpDir, "typeofmodule_multiple.luau")
		local testFile = fs.open(testPath, "w+")
		fs.write(
			testFile,
			[[
			return "hello", 42, true
		]]
		)
		fs.close(testFile)

		local typePack = luau.typeofmodule(testPath)
		assert.neq(typePack, nil)
		assert.neq(typePack.head, nil)
		assert.eq(#typePack.head, 3)

		-- Verify types: string, number, boolean
		assert.eq(typePack.head[1].tag, "string")
		assert.eq(typePack.head[2].tag, "number")
		assert.eq(typePack.head[3].tag, "boolean")
		assert.eq(typePack.tail, nil)
	end)

	suite:case("typeofmodule_returns_typepack_with_variadic_tail", function(assert)
		local testPath = path.join(tmpDir, "typeofmodule_variadic.luau")
		local testFile = fs.open(testPath, "w+")
		fs.write(
			testFile,
			[[
			local function variadic(...: string): ...string
				return ...
			end
			return variadic
		]]
		)
		fs.close(testFile)

		local typePack = luau.typeofmodule(testPath)
		assert.neq(typePack, nil)
		assert.neq(typePack.head, nil)
		assert.eq(#typePack.head, 1)

		local funcType = typePack.head[1]
		assert.eq(funcType.tag, "function")
		assert.neq(funcType.returns, nil)
		-- Variadic return should have tail set to the variadic type
		assert.neq(funcType.returns.tail, nil)
		assert.eq(funcType.returns.tail.tag, "string")
	end)

	suite:case("resolverequire", function(assert)
		local testPath = path.join(tmpDir, "resolverequire_test.luau")
		local testFile = fs.open(testPath, "w+")

		fs.write(testFile, 'print("Hello, World!")')
		local resolvedPath = luau.resolverequire("@self", testPath)
		fs.close(testFile)

		local expected = path.format(testPath):gsub("\\", "/")
		assert.eq(resolvedPath, expected)
	end)
end)
