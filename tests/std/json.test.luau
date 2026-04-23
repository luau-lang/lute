local fs = require("@std/fs")
local path = require("@std/path")
local test = require("@std/test")
local json = require("@std/json")
local stringext = require("@std/stringext")
local failure = require("@std/test/failure")

local suiteDir = "tests/std/JSONParsingTestSuite"

test.suite("JSONParsingTestSuite", function(suite)
	for _, entry in fs.listDirectory(suiteDir) do
		if entry.type ~= "file" then
			continue
		end

		local name = entry.name

		suite:case(name, function(assert)
			local p = path.join(suiteDir, name)
			local src = fs.readFileToString(path.format(p))

			-- attempt to parse .json and print the error if it fails
			local ok, parsed = pcall(function()
				return json.deserialize(src)
			end)

			if stringext.hasPrefix(name, "y_") then
				-- valid JSON: must parse
				assert.that(ok)

				-- serialize the parsed value and ensure it parses again
				local _ok2, _ser = pcall(function()
					return json.serialize(parsed)
				end)
				assert.that(_ok2)

				local _ok3 = pcall(function()
					json.deserialize(_ser)
				end)
				assert.that(_ok3)
			elseif stringext.hasPrefix(name, "n_") then
				-- invalid JSON: must fail to parse
				assert.eq(ok, false)
			else
				-- indeterminate (i_*) or other: don't assert pass/fail, but ensure call completed
				assert.eq(type(ok), "boolean")
			end
		end)
	end

	suite:case("compactSerializeHasNoSpaces", function(assert)
		assert.eq(json.serialize({ 1, 2, 3 } :: json.Array), "[1,2,3]")
		assert.eq(json.serialize({}), "[]")
		assert.eq(json.serialize(json.object({})), "{}")
		assert.eq(json.serialize({ nested = { 1, 2 } }), '{"nested":[1,2]}')
		local mixed: json.Array = { "a", { 1, 2 } :: json.Array, "b" }
		assert.eq(json.serialize(mixed), '["a",[1,2],"b"]')

		local out = json.serialize({ a = 1, b = 2 })
		assert.that(out == '{"a":1,"b":2}' or out == '{"b":2,"a":1}')
	end)

	suite:case("prettySerializeStillIndents", function(assert)
		local out = json.serialize({ 1, 2, 3 } :: json.Array, true)
		assert.eq(out, "[\n    1,\n    2,\n    3\n]")
	end)

	suite:case("jsonObjectAndasObject", function(assert)
		local obj = json.object({
			name = "Alice",
			age = 30,
		})
		assert.eq(type(obj), "table")
		assert.eq(obj.name, "Alice")
		assert.eq(obj.age, 30)
	end)

	suite:case("jsonasObjectTest", function(assert)
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
		local obj = json.asObject(maybeJson)

		if obj then
			assert.eq(type(obj), "table")
			assert.that(obj.a)
			assert.eq(type(obj.b), "table")
			local obj_b = json.asObject(obj.b)
			if obj_b then
				assert.that(obj_b.c)
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
