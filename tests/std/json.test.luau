local fs = require("@std/fs")
local path = require("@std/path")
local test = require("@std/test")
local json = require("@std/json")
local stringext = require("@std/stringext")
local failure = require("@std/test/failure")

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
				assert.truthy(ok)

				-- serialize the parsed value and ensure it parses again
				local _ok2, _ser = pcall(function()
					return json.serialize(parsed)
				end)
				assert.truthy(_ok2)

				local _ok3 = pcall(function()
					json.deserialize(_ser)
				end)
				assert.truthy(_ok3)
			elseif stringext.hasprefix(name, "n_") then
				-- invalid JSON: must fail to parse
				assert.eq(ok, false)
			else
				-- indeterminate (i_*) or other: don't assert pass/fail, but ensure call completed
				assert.eq(type(ok), "boolean")
			end
		end)
	end

	suite:case("jsonObjectAndAsObject", function(assert)
		local obj = json.object({
			name = "Alice",
			age = 30,
		})
		assert.eq(type(obj), "table")
		assert.eq(obj.name, "Alice")
		assert.eq(obj.age, 30)
	end)

	suite:case("jsonAsObjectTest", function(assert)
		local myjsonstr = [[
		{
			"a": true,
			"b": {
				"c": true,
				"d": [1, 2, 3]
			}
		}
		]]

		local maybeJson = json.deserialize(myjsonstr)
		local obj = json.asobject(maybeJson)

		if obj then
			assert.eq(type(obj), "table")
			assert.truthy(obj.a)
			assert.eq(type(obj.b), "table")
			local obj_b = json.asobject(obj.b)
			if obj_b then
				assert.truthy(obj_b.c)
				local obj_b_d = obj_b.d
				if typeof(obj_b_d) ~= "table" then
					failure.assertion(`Expected obj.b.d to be a table, was a {typeof(obj_b_d)}`)
					return
				end
				for i = 1, #obj_b_d do
					assert.eq(type(obj_b_d[i]), "number")
				end
			end
		end
	end)
end)
