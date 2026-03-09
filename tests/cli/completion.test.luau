local path = require("@std/path")
local process = require("@std/process")
local test = require("@std/test")

local lutePath = path.format(process.execpath())

test.suite("lute-completion", function(suite)
	-- General
	suite:case("no args prints usage", function(assert)
		local result = process.run({ lutePath, "completion" })

		assert.eq(result.exitcode, 0)
		assert.strcontains(result.stdout, "lute completion")
		assert.strcontains(result.stdout, "bash")
		assert.strcontains(result.stdout, "fish")
		assert.strcontains(result.stdout, "zsh")
	end)

	-- Options
	suite:case("--help prints usage", function(assert)
		local result = process.run({ lutePath, "completion", "--help" })

		assert.eq(result.exitcode, 0)
		assert.strcontains(result.stdout, "lute completion")
	end)

	suite:case("-h prints usage", function(assert)
		local result = process.run({ lutePath, "completion", "-h" })

		assert.eq(result.exitcode, 0)
		assert.strcontains(result.stdout, "lute completion")
	end)

	-- Errors
	suite:case("unsupported shell exits with error", function(assert)
		local result = process.run({ lutePath, "completion", "powershell" })

		assert.neq(result.exitcode, 0)
		assert.strcontains(result.stdout, "unsupported shell")
		assert.strcontains(result.stdout, "powershell")
	end)

	-- Shells
	suite:case("bash outputs valid script", function(assert)
		local result = process.run({ lutePath, "completion", "bash" })

		assert.eq(result.exitcode, 0)
		assert.strcontains(result.stdout, "complete -F _lute_completion lute")
		assert.strcontains(result.stdout, "_lute_discover_scripts")
	end)

	suite:case("fish outputs valid script", function(assert)
		local result = process.run({ lutePath, "completion", "fish" })

		assert.eq(result.exitcode, 0)
		assert.strcontains(result.stdout, "complete -c lute")
		assert.strcontains(result.stdout, "__lute_discover_scripts")
	end)

	suite:case("zsh outputs valid script", function(assert)
		local result = process.run({ lutePath, "completion", "zsh" })

		assert.eq(result.exitcode, 0)
		assert.strcontains(result.stdout, "compdef _lute lute")
		assert.strcontains(result.stdout, "_lute_discover_scripts")
	end)
end)
