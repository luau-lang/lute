local test = require("@std/test")
local toml = require("@batteries/toml")

test.suite("TOML deserialization", function(suite)
	suite:case("simpleKeyValue", function(assert)
		local result: any = toml.deserialize('name = "hello"\ncount = 42\nenabled = true\n')
		assert.eq(result.name, "hello")
		assert.eq(result.count, 42)
		assert.eq(result.enabled, true)
	end)

	suite:case("nestedTableViaSection", function(assert)
		local result: any = toml.deserialize('[server]\nhost = "localhost"\nport = 8080\n')
		assert.eq(result.server.host, "localhost")
		assert.eq(result.server.port, 8080)
	end)

	suite:case("dottedTablePath", function(assert)
		local result: any = toml.deserialize("[a.b]\nvalue = 1\n")
		assert.eq(result.a.b.value, 1)
	end)

	suite:case("quotedKeyWithDotInTableHeader", function(assert)
		local input = '[images."icon.png"]\nassetId = "123"\n'
		local result: any = toml.deserialize(input)
		assert.neq(result.images, nil)
		assert.neq(result.images["icon.png"], nil)
		assert.eq(result.images["icon.png"].assetId, "123")
	end)

	suite:case("singleQuotedKeyWithDotInTableHeader", function(assert)
		local input = "[images.'icon.png']\nassetId = \"456\"\n"
		local result: any = toml.deserialize(input)
		assert.neq(result.images, nil)
		assert.neq(result.images["icon.png"], nil)
		assert.eq(result.images["icon.png"].assetId, "456")
	end)

	suite:case("mixedDottedAndQuotedPath", function(assert)
		local input = '[a."b.c".d]\nvalue = 1\n'
		local result: any = toml.deserialize(input)
		assert.neq(result.a, nil)
		assert.neq(result.a["b.c"], nil)
		assert.neq(result.a["b.c"].d, nil)
		assert.eq(result.a["b.c"].d.value, 1)
	end)

	suite:case("quotedKeyInKeyValuePair", function(assert)
		local result: any = toml.deserialize('"icon.png" = "value"\n')
		assert.eq(result["icon.png"], "value")
	end)

	suite:case("specialValues", function(assert)
		local result: any = toml.deserialize("a = inf\nb = -inf\nc = nan\n")
		assert.eq(result.a, math.huge)
		assert.eq(result.b, -math.huge)
		assert.neq(result.c, result.c) -- NaN ~= NaN
	end)
end)

test.suite("TOML serialization", function(suite)
	suite:case("keyWithDotIsQuoted", function(assert)
		local input = { images = { ["icon.png"] = { assetId = "123" } } }
		local output = toml.serialize(input)
		assert.strContains(output, '"icon.png"')
	end)

	suite:case("roundTrip", function(assert)
		local input = '[images."icon.png"]\nassetId = "123"\nhash = "abc"\n'
		local first: any = toml.deserialize(input)
		local serialized = toml.serialize(first)
		local second: any = toml.deserialize(serialized)
		assert.eq(second.images["icon.png"].assetId, "123")
		assert.eq(second.images["icon.png"].hash, "abc")
	end)
end)
