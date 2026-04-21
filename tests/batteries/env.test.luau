local env = require("@batteries/env")
local fs = require("@std/fs")
local path = require("@std/path")
local system = require("@std/system")
local test = require("@std/test")

local root = path.format(path.join(system.tmpdir(), "lute-env-battery"))
local envFile = path.join(root, ".env")

test.suite(".env parsing", function(suite)
	suite:case("parsesCommonAssignments", function(assert)
		local parsed = env.parse([[
# comment
FOO=bar
BAR = baz # inline comment
EMPTY=
export BEEP=boop
HASH=literal\#hash
]])

		assert.eq(parsed.FOO, "bar")
		assert.eq(parsed.BAR, "baz")
		assert.eq(parsed.EMPTY, "")
		assert.eq(parsed.BEEP, "boop")
		assert.eq(parsed.HASH, "literal#hash")
	end)

	suite:case("parsesQuotedAndMultilineValues", function(assert)
		local parsed = env.parse([[
SINGLE='hello # world'
DOUBLE="hello\nworld"
MULTI="line 1
line 2"
ESCAPED="cost: \$5"
]])

		assert.eq(parsed.SINGLE, "hello # world")
		assert.eq(parsed.DOUBLE, "hello\nworld")
		assert.eq(parsed.MULTI, "line 1\nline 2")
		assert.eq(parsed.ESCAPED, "cost: $5")
	end)

	suite:case("expandsVariablesWithFallbackOperators", function(assert)
		local parsed = env.parse(
			[[
ROOT=/workspace
BIN=${ROOT}/bin
HOME_DIR=$HOME
DEFAULTED=${MISSING:-fallback}
EMPTY_FALLBACK=${EMPTY:-fallback}
SET_ALT=${ROOT:+yes}
UNSET_ALT=${MISSING:+no}
]],
			{
				expand = true,
				env = {
					HOME = "/users/lute",
					EMPTY = "",
				},
			}
		)

		assert.eq(parsed.ROOT, "/workspace")
		assert.eq(parsed.BIN, "/workspace/bin")
		assert.eq(parsed.HOME_DIR, "/users/lute")
		assert.eq(parsed.DEFAULTED, "fallback")
		assert.eq(parsed.EMPTY_FALLBACK, "fallback")
		assert.eq(parsed.SET_ALT, "yes")
		assert.eq(parsed.UNSET_ALT, "")
	end)

	suite:case("rejectsCircularExpansion", function(assert)
		assert.throwsWith("circular env expansion detected: A -> B -> A", function()
			env.parse("A=$B\nB=$A\n", {
				expand = true,
			})
		end)
	end)
end)

test.suite(".env serialization", function(suite)
	suite:case("roundTripsSpecialValues", function(assert)
		local serialized = env.serialize({
			EMPTY = "",
			MULTI = "line 1\nline 2",
			HASH = "a#b",
			MONEY = "$5",
			SIMPLE = "value",
			SPACED = "hello world",
		})

		local parsed = env.parse(serialized, { expand = true })
		assert.eq(parsed.EMPTY, "")
		assert.eq(parsed.MULTI, "line 1\nline 2")
		assert.eq(parsed.HASH, "a#b")
		assert.eq(parsed.MONEY, "$5")
		assert.eq(parsed.SIMPLE, "value")
		assert.eq(parsed.SPACED, "hello world")
	end)
end)

test.suite(".env file helpers", function(suite)
	suite:beforeEach(function()
		if fs.exists(root) then
			fs.removeDirectory(root, { recursive = true })
		end
		fs.createDirectory(root)
	end)

	suite:case("loadReadsAndExpandsFromDisk", function(assert)
		fs.writeStringToFile(envFile, "ROOT=/app\nBIN=${ROOT}/bin\n")
		local parsed = env.load(envFile, { expand = true })

		assert.eq(parsed.ROOT, "/app")
		assert.eq(parsed.BIN, "/app/bin")
	end)

	suite:case("configAppliesWithoutOverridingByDefault", function(assert)
		fs.writeStringToFile(envFile, "EXISTING=from-file\nNEW=value\n")

		local target: env.Environment = {
			EXISTING = "keep-me",
		}

		local parsed = env.config({
			path = envFile,
			target = target,
		})

		assert.eq(parsed.EXISTING, "from-file")
		assert.eq(parsed.NEW, "value")
		assert.eq(target.EXISTING, "keep-me")
		assert.eq(target.NEW, "value")
	end)

	suite:case("configCanOverrideExistingValues", function(assert)
		fs.writeStringToFile(envFile, "EXISTING=from-file\n")

		local target: env.Environment = {
			EXISTING = "keep-me",
		}

		env.config({
			path = envFile,
			target = target,
			override = true,
		})

		assert.eq(target.EXISTING, "from-file")
	end)
end)
