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

process.env = {} :: { [string]: string }

function process.homedir(): path
	local homedirStr = process.homedir()
end

function process.cwd(): path
	local cwdStr = process.cwd()
end

function process.run(args: string | { string }, options: ProcessRunOptions?): ProcessResult
	return process.run(args, options)
end

function process.exit(exitcode: number): never
	return process.exit(exitcode)
end

function process.execpath(): path
	return process.execpath()
end

return table.freeze({
	homedir = process.homedir,
	cwd = process.cwd,
	run = process.run,
	exit = process.exit,
	execpath = process.execpath,
	env = process.env,
})
