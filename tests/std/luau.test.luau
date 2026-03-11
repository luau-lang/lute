local fs = require("@std/fs")
local luau = require("@std/luau")
local path = require("@std/path")
local system = require("@std/system")
local test = require("@std/test")

local tmpDir = system.tmpdir()

test.suite("LuauTypeOfModuleSuite", function(suite)
	suite:case("typeofmoduleReturnsTable", function(assert)
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
		if not typePack then
			error("typePack should not be nil")
		end

		-- Verify TypePack structure: { head: {type}?, tail: typepack? }
		assert.eq(typePack.tag, "typepack")

		assert.neq(typePack.head, nil)
		if not typePack.head then
			error("typePack.head should not be nil")
		end
		assert.eq(typePack.tail, nil) -- No tail for simple return

		-- Verify head is an array with one element (the table type)
		assert.eq(#typePack.head, 1)

		local returnType = typePack.head[1]
		assert.neq(returnType, nil)
		assert.eq(returnType.tag, "table")

		-- Verify table has properties
		assert.neq(returnType.properties, nil)

		-- Find the example_string_func property
		local foundProperty = false
		for name, prop in pairs(returnType.properties) do
			if name == "example_string_func" then
				foundProperty = true
				assert.neq(prop.read, nil)
				local funcType = prop.read
				if not funcType then
					error("Function type should not be nil")
				end

				assert.eq(funcType.tag, "function")
				-- Verify function returns string
				assert.neq(funcType.returns, nil)
				assert.neq(funcType.returns.head, nil)
				if not funcType.returns.head then
					error("Function.returns.head should not be nil")
				end

				assert.eq(#funcType.returns.head, 1)
				assert.eq(funcType.returns.head[1].tag, "string")
				break
			end
		end
		assert.eq(foundProperty, true, "Should find example_string_func property")
	end)

	suite:case("typeofmoduleReturnsTypepackWithMultipleValues", function(assert)
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
		if not typePack then
			error("typePack should not be nil")
		end

		-- Verify TypePack structure: { head: {type}?, tail: typepack? }
		assert.eq(typePack.tag, "typepack")

		-- Head: string, number
		assert.neq(typePack.head, nil)
		if not typePack.head then
			error("typePack.head should not be nil")
		end
		assert.eq(#typePack.head, 3)

		assert.eq(typePack.head[1].tag, "string")
		assert.eq(typePack.head[2].tag, "number")
		assert.eq(typePack.head[3].tag, "boolean")
	end)

	suite:case("typeofmoduleReturnsTypepackWithVariadicTail", function(assert)
		local testPath = path.join(tmpDir, "typeofmodule_variadic.luau")
		local testFile = fs.open(testPath, "w+")
		fs.write(
			testFile,
			[[
			local function variadic_func(...: string): ...string
				return ...
			end
			return variadic_func
		]]
		)
		fs.close(testFile)

		local typePack = luau.typeofmodule(testPath)
		assert.neq(typePack, nil)
		if not typePack then
			error("typePack should not be nil")
		end

		assert.eq(typePack.tag, "typepack")

		assert.neq(typePack.head, nil)
		if not typePack.head then
			error("typePack.head should not be nil")
		end
		assert.eq(#typePack.head, 1)

		local funcType = typePack.head[1]
		assert.eq(funcType.tag, "function")
		assert.neq(funcType.returns, nil)

		assert.eq(funcType.returns.tag, "variadic")

		assert.neq(funcType.returns.type, nil)
		if not funcType.returns.type then
			error("Function.returns.type should not be nil")
		end
		assert.eq(funcType.returns.type.tag, "string")
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
