--!strict
-- @std/process
-- stdlib for `@lute/process`
-- Provides process-related utility functions that handles file paths as path types instead of strings

local process = require("@lute/process")
local pathlib = require("@std/path")

local processlib = {}

--- How a child process's standard streams should be handled:
--- - `"default"`: Capture stdout and stderr to pipes, accessible via `ProcessResult`.
--- - `"inherit"`: Pass the parent process's stdio streams through to the child.
--- - `"none"`: Discard the child's stdio streams.
export type StdioKind = process.StdioKind
--- Options for `process.run`: controls stdio handling, working directory, environment, etc.
export type ProcessRunOptions = process.ProcessRunOptions
--- Options for `process.system`: controls stdio handling, working directory, environment, etc.
export type ProcessSystemOptions = process.ProcessSystemOptions
--- The result of a completed process, including exit code and captured stdout/stderr.
export type ProcessResult = process.ProcessResult
--- A structured, platform-aware file system path.
export type Path = pathlib.Path
--- Anything that can be used as a path: a string, a `Path`, or raw path data.
export type Pathlike = pathlib.Pathlike

--- Returns the current user's home directory as a `Path`.
function processlib.homedir(): Path
	return pathlib.parse(process.homedir())
end

--- Returns the current working directory as a `Path`.
function processlib.cwd(): Path
	return pathlib.parse(process.cwd())
end

--- Runs the program given by `args[1]` with the remaining entries as arguments.
--- Returns the process result including exit code and any captured output.
function processlib.run(args: { string }, options: ProcessRunOptions?): ProcessResult
	return process.run(args, options)
end

--- Runs `command` through the system shell. Returns the process result.
function processlib.system(command: string, options: ProcessSystemOptions?): ProcessResult
	return process.system(command, options)
end

--- Exits the current process with the given `exitcode`.
function processlib.exit(exitcode: number): never
	return process.exit(exitcode)
end

--- Returns the path of the currently running lute executable as a `Path`.
function processlib.execPath(): Path
	return pathlib.parse(process.execPath())
end

-- re-exports
processlib.args = process.args
processlib.env = process.env

return table.freeze(processlib)
