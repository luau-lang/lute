local luau = require("@std/luau")
local env = require("@std/test/env")
local runner = require("@std/test/runner")
local types = require("@std/test/types")
local filter = require("./filter")

export type Result<T, E> = { __tag: "ok", value: T } | { __tag: "err", error: E }

local function reset()
	table.clear(env.anonymous)
	table.clear(env.suites)
	table.clear(env.suiteindex)
	table.clear(env.caseindex)
end

local function runfile(
	args: { file: string, suite: string?, case: string?, verbose: boolean? }
): Result<types.TestRunResult, string>
	reset()

	local ok, err = pcall(luau.loadModule, args.file, nil)
	if not ok then
		return { __tag = "err", error = tostring(err) }
	end

	local filtered = filter.filtertests(env, args.suite, args.case)
	return { __tag = "ok", value = runner.run(filtered, { verbose = args.verbose == true }) }
end

return table.freeze({ runfile = runfile })
