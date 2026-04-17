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

test.suite("TOMLInlineArrayDeserialization", function(suite)
	suite:case("singleStringElement", function(assert)
		local result: any = toml.deserialize('args = ["--stdio"]\n')
		assert.neq(result.args, nil)
		assert.eq(#result.args, 1)
		assert.eq(result.args[1], "--stdio")
	end)

	suite:case("multipleStringElements", function(assert)
		local result: any = toml.deserialize('args = ["--stdio", "--port", "1234"]\n')
		assert.eq(#result.args, 3)
		assert.eq(result.args[1], "--stdio")
		assert.eq(result.args[2], "--port")
		assert.eq(result.args[3], "1234")
	end)

	suite:case("numberElements", function(assert)
		local result: any = toml.deserialize("ports = [8080, 9090]\n")
		assert.eq(#result.ports, 2)
		assert.eq(result.ports[1], 8080)
		assert.eq(result.ports[2], 9090)
	end)

	suite:case("booleanElements", function(assert)
		local result: any = toml.deserialize("flags = [true, false, true]\n")
		assert.eq(#result.flags, 3)
		assert.eq(result.flags[1], true)
		assert.eq(result.flags[2], false)
		assert.eq(result.flags[3], true)
	end)

	suite:case("mixedPrimitiveElements", function(assert)
		local result: any = toml.deserialize('mixed = ["hello", 42, true]\n')
		assert.eq(#result.mixed, 3)
		assert.eq(result.mixed[1], "hello")
		assert.eq(result.mixed[2], 42)
		assert.eq(result.mixed[3], true)
	end)

	suite:case("inlineArrayUnderSectionHeader", function(assert)
		local input = '[mcp_servers.Roblox_Studio]\nargs = ["--stdio"]\ncommand = "/path/cmd"\nenabled = true\n'
		local result: any = toml.deserialize(input)
		assert.neq(result.mcp_servers, nil)
		assert.neq(result.mcp_servers.Roblox_Studio, nil)
		assert.eq(result.mcp_servers.Roblox_Studio.enabled, true)
		assert.eq(result.mcp_servers.Roblox_Studio.command, "/path/cmd")
		assert.eq(#result.mcp_servers.Roblox_Studio.args, 1)
		assert.eq(result.mcp_servers.Roblox_Studio.args[1], "--stdio")
	end)
end)

test.suite("TOMLInlineArraySerialization", function(suite)
	suite:case("flatStringArrayIsInline", function(assert)
		local output = toml.serialize({ args = { "--stdio" } })
		assert.strContains(output, 'args = ["--stdio"]')
	end)

	suite:case("flatNumberArrayIsInline", function(assert)
		local output = toml.serialize({ ports = { 8080, 9090 } })
		assert.strContains(output, "ports = [8080, 9090]")
	end)

	suite:case("flatMixedArrayIsInline", function(assert)
		local output = toml.serialize({ mixed = { "hello", 42 } })
		assert.strContains(output, 'mixed = ["hello", 42]')
	end)

	suite:case("arrayOfTablesStillUsesDoubleBrackets", function(assert)
		local output = toml.serialize({ items = { { name = "a" }, { name = "b" } } })
		assert.strContains(output, "[[items]]")
	end)

	suite:case("sectionHeaderGeneratedWhenTableHasInlineArray", function(assert)
		local input = {
			mcp_servers = {
				Roblox_Studio = {
					args = { "--stdio" },
					command = "/path/cmd",
					enabled = true,
				},
			},
		}
		local output = toml.serialize(input)
		assert.strContains(output, "[mcp_servers.Roblox_Studio]")
		assert.strContains(output, 'args = ["--stdio"]')
		assert.strContains(output, 'command = "/path/cmd"')
		assert.strContains(output, "enabled = true")
	end)

	suite:case("inlineArrayNotEmittedAsArrayOfTables", function(assert)
		-- flat arrays must NOT produce [[...]] array-of-tables syntax
		local output = toml.serialize({ args = { "--stdio" } })
		assert.eq(string.find(output, "[[", 1, true), nil)
	end)
end)

test.suite("TOMLInlineArrayRoundTrip", function(suite)
	suite:case("flatStringArray", function(assert)
		local serialized = toml.serialize({ args = { "--stdio", "--port", "1234" } })
		local result: any = toml.deserialize(serialized)
		assert.eq(#result.args, 3)
		assert.eq(result.args[1], "--stdio")
		assert.eq(result.args[2], "--port")
		assert.eq(result.args[3], "1234")
	end)

	suite:case("flatNumberArray", function(assert)
		local serialized = toml.serialize({ ports = { 8080, 9090 } })
		local result: any = toml.deserialize(serialized)
		assert.eq(#result.ports, 2)
		assert.eq(result.ports[1], 8080)
		assert.eq(result.ports[2], 9090)
	end)

	suite:case("mcpServerConfig", function(assert)
		local input: any = {
			mcp_servers = {
				Roblox_Studio = {
					args = { "--stdio" },
					command = "/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP",
					enabled = true,
				},
			},
		}
		local result: any = toml.deserialize(toml.serialize(input))
		local server = result.mcp_servers.Roblox_Studio
		assert.neq(server, nil)
		assert.eq(server.enabled, true)
		assert.eq(server.command, "/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP")
		assert.eq(#server.args, 1)
		assert.eq(server.args[1], "--stdio")
	end)
end)
