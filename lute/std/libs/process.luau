--!strict
-- @std/process
-- stdlib for `@lute/process`
-- Provides process-related utility functions that handles file paths as path types instead of strings

local process = require("@lute/process")
local pathlib = require("@std/path")

local processlib = {}

export type StdioKind = process.StdioKind
export type ProcessRunOptions = process.ProcessRunOptions
export type ProcessSystemOptions = process.ProcessSystemOptions
export type ProcessResult = process.ProcessResult
export type Path = pathlib.Path
export type Pathlike = pathlib.Pathlike

function processlib.homedir(): Path
	return pathlib.parse(process.homedir())
end

function processlib.cwd(): Path
	return pathlib.parse(process.cwd())
end

function processlib.run(args: { string }, options: ProcessRunOptions?): ProcessResult
	return process.run(args, options)
end

function processlib.system(command: string, options: ProcessSystemOptions?): ProcessResult
	return process.system(command, options)
end

function processlib.exit(exitcode: number): never
	return process.exit(exitcode)
end

function processlib.execPath(): Path
	return pathlib.parse(process.execPath())
end

-- re-exports
processlib.args = process.args
processlib.env = process.env

return table.freeze(processlib)
