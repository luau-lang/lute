local test = require("@std/test")
local base64 = require("@batteries/base64")

local function enc(s: string): string
	return buffer.tostring(base64.encode(buffer.fromstring(s)))
end
local function dec(s: string): string
	return buffer.tostring(base64.decode(buffer.fromstring(s)))
end

-- RFC 4648 test vectors
local testVectors = {
	{ "", "" },
	{ "f", "Zg==" },
	{ "fo", "Zm8=" },
	{ "foo", "Zm9v" },
	{ "foob", "Zm9vYg==" },
	{ "fooba", "Zm9vYmE=" },
	{ "foobar", "Zm9vYmFy" },
	{ "foobarb", "Zm9vYmFyYg==" },
	{ "foobarba", "Zm9vYmFyYmE=" },
	{ "foobarbaz", "Zm9vYmFyYmF6" },
}

local invalidInputs = {
	"SGVsbG8\0",
	"SGVsbG8\255",
	"Hell@oWorld!",
	"Test1#23",
	"DataMon$ey",
	"SGVsbG8-V29ybGQ_",
	"SGVs=bG8=",
}

local invalidLastBytes = {
	"====", -- all padding
	"A==A", -- char after padding
	"A", -- invalid length
	"AB==", -- impossible sequence
	"AAB=", -- impossible sequence
}

test.suite("Base64", function(suite)
	for _, vector in ipairs(testVectors) do
		local input = vector[1]
		local expected_encoded = vector[2]

		suite:case("encode: '" .. input .. "'", function(assert)
			local encoded = enc(input)
			assert.eq(expected_encoded, encoded)
		end)

		suite:case("decode: '" .. expected_encoded .. "'", function(assert)
			local decoded = dec(expected_encoded)
			assert.eq(input, decoded)
		end)
	end

	for _, invalid in invalidInputs do
		suite:case("invalidDecode: '" .. invalid .. "'", function(assert)
			assert.throws(function()
				dec(invalid)
			end)
		end)
	end

	for _, invalid in invalidLastBytes do
		suite:case("invalidDecodeLastBytes: '" .. invalid .. "'", function(assert)
			assert.throws(function()
				dec(invalid)
			end)
		end)
	end
end)
