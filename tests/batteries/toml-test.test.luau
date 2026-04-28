-- Tests the toml battery against the official toml-test suite.
-- Must be run from the repo root (where extern/toml-test/tests/ lives).
--
-- Valid tests: each .toml file is parsed and compared against its .json
-- counterpart using the toml-test tagged-value format.
-- Invalid tests: each .toml file must cause toml.deserialize to throw.

local toml = require("@batteries/toml")

local fs = require("@std/fs")
local json = require("@std/json")
local test = require("@std/test")

local VALID_DIR = "extern/toml-test/tests/valid"
local INVALID_DIR = "extern/toml-test/tests/invalid"
local VERSION_FILE = "extern/toml-test/tests/files-toml-1.1.0"

-- Build a set of paths that are valid for TOML 1.1 (relative to extern/toml-test/tests/)
local toml11: { [string]: boolean } = {}
for line in string.gmatch(fs.readFileToString(VERSION_FILE), "[^\n]+") do
	toml11[line] = true
end

-- Returns true if the full file path is included in the TOML 1.1 test set.
local function isToml11(fullPath: string): boolean
	-- fullPath is e.g. "extern/toml-test/tests/valid/bool/bool.toml"
	-- version file entries are e.g. "valid/bool/bool.toml"
	local rel = string.sub(fullPath, #"extern/toml-test/tests/" + 1)
	return toml11[rel] == true
end

local function collectTomlFiles(dir: string, results: { string }): ()
	local entries = fs.listDirectory(dir)

	for _, entry in entries do
		local fullPath = `{dir}/{entry.name}`
		if entry.type == "dir" then
			collectTomlFiles(fullPath, results)
		elseif entry.type == "file" and string.match(entry.name, "%.toml$") then
			table.insert(results, fullPath)
		end
	end
end

-- Detect a toml-test tagged leaf: { type = "<string>", value = <any> }
-- @std/json adds a userdata marker key to every deserialized object, so we
-- skip userdata keys when counting.
local function isTagged(obj: any): boolean
	if typeof(obj) ~= "table" then
		return false
	end

	local count = 0
	for k in obj do
		if typeof(k) ~= "userdata" then
			count += 1
		end
	end

	return count == 2 and typeof(obj.type) == "string" and obj.value ~= nil
end

-- Recursively convert a toml-test JSON value tree into plain Lua values.
-- Tagged leaves are converted to their Lua equivalents; structural tables and
-- arrays are recursed into. Userdata marker keys from the JSON deserializer
-- are skipped.
local function flattenExpected(value: any): any
	if typeof(value) ~= "table" then
		return value
	end

	if not isTagged(value) then
		local result: { [any]: any } = {}
		for k, v in value do
			if typeof(k) ~= "userdata" then
				result[k] = flattenExpected(v)
			end
		end
		return result
	end

	local typ: string = value.type
	local val: any = value.value

	if typ == "bool" then
		return val == "true"
	end

	if typ == "integer" then
		return tonumber(val)
	end

	if typ == "float" then
		if val == "inf" or val == "+inf" then
			return math.huge
		elseif val == "-inf" then
			return -math.huge
		elseif val == "nan" then
			return 0 / 0
		else
			return tonumber(val)
		end
	end

	-- string, datetime, datetime-local, date-local, time-local
	-- For datetime/time types, normalize trailing zeros in fractional seconds
	-- so ".600" and ".6" compare equal (toml-test has inconsistent precision).
	if typ ~= "string" then
		-- FIXME(Luau): bidirectional typechecking should allow us to avoid this annotation
		return (val :: string):gsub("%.(%d+)", function(frac: string): string
			local stripped = frac:gsub("0+$", "")
			return `.{if stripped ~= "" then stripped else "0"}`
		end)
	end

	return val :: string
end

-- Deep equality that handles NaN == NaN (which `==` does not).
local function deepEq(a: any, b: any, path: string): (boolean, string)
	if typeof(a) == "number" and typeof(b) == "number" then
		if a ~= a and b ~= b then
			return true, "" -- both NaN
		end

		if a == b then
			return true, ""
		end

		return false, `{path}: {a} ~= {b}`
	end

	if typeof(a) ~= typeof(b) then
		return false, `{path}: got {typeof(a)} ({tostring(a)}) but expected {typeof(b)} ({tostring(b)})`
	end

	if typeof(a) ~= "table" then
		if a == b then
			return true, ""
		end

		return false, `{path}: {tostring(a)} ~= {tostring(b)}`
	end

	for k, v in a :: { [any]: any } do
		local keyPath = if path == "" then tostring(k) else `{path}.{k}`

		local ok, msg = deepEq(v, (b :: any)[k], keyPath)
		if not ok then
			return false, msg
		end
	end

	for k in b :: { [any]: any } do
		if (a :: any)[k] == nil then
			local keyPath = if path == "" then tostring(k) else `{path}.{k}`

			return false, `{keyPath}: key present in expected but missing in actual`
		end
	end

	return true, ""
end

-- "extern/toml-test/tests/valid/bool/bool.toml" -> "bool/bool"
local function testName(fullPath: string, baseDir: string): string
	local rel = string.sub(fullPath, #baseDir + 2)
	return string.sub(rel, 1, -6)
end

local validFiles: { string } = {}
local invalidFiles: { string } = {}
collectTomlFiles(VALID_DIR, validFiles)
collectTomlFiles(INVALID_DIR, invalidFiles)

-- Filter to only TOML 1.1 tests
local function filter(files: { string }): { string }
	local out: { string } = {}
	for _, path in files do
		if isToml11(path) then
			table.insert(out, path)
		end
	end
	return out
end

validFiles = filter(validFiles)
invalidFiles = filter(invalidFiles)

table.sort(validFiles)
table.sort(invalidFiles)

test.suite("toml-test-valid", function(suite)
	for _, path in validFiles do
		local name = testName(path, VALID_DIR)
		local jsonPath = `{string.sub(path, 1, -6)}.json`

		suite:case(name, function(assert)
			local actual: any = toml.deserialize(fs.readFileToString(path))
			local expected = flattenExpected(json.deserialize(fs.readFileToString(jsonPath)))
			local ok, msg = deepEq(actual, expected, "")
			assert.that(ok, msg)
		end)
	end
end)

test.suite("toml-test-invalid", function(suite)
	for _, path in invalidFiles do
		local name = testName(path, INVALID_DIR)

		suite:case(name, function(assert)
			assert.throws(function()
				toml.deserialize(fs.readFileToString(path))
			end)
		end)
	end
end)
