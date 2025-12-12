local fs = require("@std/fs")
local path = require("@std/path")
local test = require("@std/test")
local json = require("@std/json")
local stringext = require("@std/stringext")

local suiteDir = "tests/std/JSONParsingTestSuite"

test.suite("JSONParsingTestSuite", function(suite)
	for _, entry in fs.listdirectory(suiteDir) do
		if entry.type ~= "file" then
			continue
		end

		local name = entry.name

		suite:case(name, function(assert)
			local p = path.join(suiteDir, name)
			local src = fs.readfiletostring(path.format(p))

			-- attempt to parse .json and print the error if it fails
			local ok, parsed = pcall(function()
				return json.deserialize(src)
			end)

			if stringext.hasprefix(name, "y_") then
				-- valid JSON: must parse
				assert.eq(ok, true)

				-- serialize the parsed value and ensure it parses again
				local _ok2, _ser = pcall(function()
					return json.serialize(parsed)
				end)
				assert.eq(_ok2, true)

				local _ok3 = pcall(function()
					json.deserialize(_ser)
				end)
				assert.eq(_ok3, true)
			elseif stringext.hasprefix(name, "n_") then
				-- invalid JSON: must fail to parse
				assert.eq(ok, false)
			else
				-- indeterminate (i_*) or other: don't assert pass/fail, but ensure call completed
				assert.eq(type(ok), "boolean")
			end
		end)
	end

	suite:case("json_object_and_asobject", function(assert)
		local obj = json.object({
			name = "Alice",
			age = 30,
		})
		assert.eq(type(obj), "table")
		assert.eq(obj.name, "Alice")
		assert.eq(obj.age, 30)
	end)

	suite:case("json_asobject_test", function(assert)
		-- local myjsonstr = "{\"a\": true, \"b\": { \"c\": true } }"
		local myjsonstr = [[
		{
			"a": true,
			"b": {
				"c": true
			}
		}
		]]

		local maybeJson = json.deserialize(myjsonstr)
		local obj = json.asobject(maybeJson)

		if obj then
			assert.eq(type(obj), "table")
			assert.eq(obj.a, true)
			assert.eq(type(obj.b), "table")
			if json.asobject(obj.b) then
				assert.eq(obj.b.c, true)
			end
		end
	end)
end)

test.run()
