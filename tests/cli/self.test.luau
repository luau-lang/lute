local path = require("@std/path")
local process = require("@std/process")
local test = require("@std/test")

local release = require("@commands/self/release")

local lutePath = path.format(process.execPath())

local function run(...: string): process.ProcessResult
	return process.run({ lutePath, "self", ... })
end

test.suite("LuteSelf", function(suite)
	suite:case("showsHelp", function(assert)
		local result = run("--help")

		assert.eq(result.exitcode, 0)
		assert.strContains(result.stdout, "Usage: lute self <command>")
		assert.strContains(result.stdout, "install")
		assert.strContains(result.stdout, "update")
		assert.strContains(result.stdout, "uninstall")
	end)

	suite:case("showsSubcommandHelp", function(assert)
		for _, command in { "install", "update", "uninstall" } do
			local result = run(command, "--help")

			assert.eq(result.exitcode, 0)
			assert.strContains(result.stdout, `Usage: lute self {command}`)
		end
	end)

	suite:case("rejectsUnknownCommand", function(assert)
		local result = run("unknown")

		assert.eq(result.exitcode, 1)
		assert.strContains(result.stdout, "Unknown command: unknown")
	end)

	suite:case("normalizesReleaseTags", function(assert)
		assert.eq(release.normalizeTag("1.0.1"), "v1.0.1")
		assert.eq(release.normalizeTag("v1.0.1"), "v1.0.1")
		assert.eq(release.normalizeTag(" V1.0.1 "), "v1.0.1")
	end)
end)
