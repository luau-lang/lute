--!strict
-- @std/process
-- stdlib for `@lute/process`
-- Provides process-related utility functions that handles file paths as path types instead of strings

local process = require("@lute/process")
local stdPath = require("@std/path")

type StdioKind = process.StdioKind
type ProcessRunOptions = process.ProcessRunOptions
type ProcessResult = process.ProcessResult
type path = stdPath.path
type pathlike = stdPath.pathlike

function homedir(): path
	return stdPath.parse(process.homedir())
end

function cwd(): path
	return stdPath.parse(process.cwd())
end

function run(args: string | { string }, options: ProcessRunOptions?): ProcessResult
	return process.run(args, options)
end

function exit(exitcode: number): never
	return process.exit(exitcode)
end

function execpath(): path
	return stdPath.parse(process.execpath())
end

return table.freeze({
	env = process.env,
	homedir = homedir,
	cwd = cwd,
	run = run,
	exit = exit,
	execpath = execpath,
})
