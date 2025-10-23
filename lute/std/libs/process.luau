--!strict
-- @std/process
-- stdlib for `@lute/process`
-- Provides process-related utility functions that handles file paths as path types instead of strings

local process = require("@lute/process")
local pathlib = require("@std/path")

export type stdiokind = process.StdioKind
export type processrunoptions = process.ProcessRunOptions
export type processresult = process.ProcessResult
export type path = pathlib.path
export type pathlike = pathlib.pathlike

local function homedir(): path
	return pathlib.parse(process.homedir())
end

local function cwd(): path
	return pathlib.parse(process.cwd())
end

local function run(args: string | { string }, options: processrunoptions?): processresult
	return process.run(args, options)
end

local function exit(exitcode: number): never
	return process.exit(exitcode)
end

local function execpath(): path
	return pathlib.parse(process.execpath())
end

return table.freeze({
	env = process.env,
	homedir = homedir,
	cwd = cwd,
	run = run,
	exit = exit,
	execpath = execpath,
})
